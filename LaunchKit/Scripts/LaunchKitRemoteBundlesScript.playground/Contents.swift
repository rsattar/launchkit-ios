#!/usr/bin/env xcrun swift
import Foundation

// EXIT IF NOT RUNNING WITH PARAM
if Process.arguments.count <= 1 {
    print("No API token supplied. Supply API token as first parameter. Get an api token at https://launchkit.io/account/sdk-tokens")
    exit(EXIT_FAILURE)
}

let apiToken = Process.arguments[1]
let useLocalServer: Bool
if Process.arguments.indexOf("-local") != nil {
    useLocalServer = true
} else {
    useLocalServer = false
}
let verboseDebugging: Bool
if Process.arguments.indexOf("-verbose") != nil {
    verboseDebugging = true;
} else {
    verboseDebugging = false;
}


let apiBaseUrlString: String
if useLocalServer {
    apiBaseUrlString = "http://localhost:9101"
} else {
    apiBaseUrlString = "https://api.launchkit.io"
}

let env = NSProcessInfo.processInfo().environment

// Useful for storing intermediate files (like cached bundles)
let configurationBuildDir: NSString
// Useful for finding the final "build" destination. Things like 
// intermediate files should not use targetBuildDir
let targetBuildDir: NSString
let appExecutableDir: NSString
let infoPlistPath: String
if  let configDir = env["CONFIGURATION_BUILD_DIR"],
    let buildDir = env["TARGET_BUILD_DIR"],
    let executableDir = env["EXECUTABLE_FOLDER_PATH"],
    let plistPath = env["INFOPLIST_PATH"] {

    configurationBuildDir = configDir
    targetBuildDir = buildDir
    appExecutableDir = executableDir
    infoPlistPath = targetBuildDir.stringByAppendingPathComponent(plistPath as String);
} else {
    configurationBuildDir = "."
    targetBuildDir = "."
    appExecutableDir = ""
    infoPlistPath = ""
}

let debugBuild: Int
if let configurationString = env["CONFIGURATION"] where configurationString == "Debug" {
    debugBuild = 1
} else {
    debugBuild = 0
}
if verboseDebugging {
    print("Debug build: \(debugBuild), local server: \(useLocalServer)")
}


var appInfoPlist = NSMutableDictionary(contentsOfFile: infoPlistPath)
let appBundle: String
let appBundleVersion: String
let appBuildNumber: String

if let appInfoPlist = appInfoPlist,
    let bundle = appInfoPlist[kCFBundleIdentifierKey as String] as? String,
    let version = appInfoPlist["CFBundleShortVersionString"] as? String,
    let build = appInfoPlist["CFBundleVersion"] as? String
{
    appBundle = bundle
    appBundleVersion = version
    appBuildNumber = build
} else {
    appBundle = ""
    appBundleVersion = ""
    appBuildNumber = ""
}

// TODO(Riz):
let appOSVersion: String = ""
let hardwareModel: String = ""

if verboseDebugging {
    print("Bundle: \(appBundle)")
    print("Version: \(appBundleVersion)")
    print("Build: \(appBuildNumber)")
    print("App OS Version: \(appOSVersion)")
    print("hardwareModel: \(hardwareModel)")
}

let cachedBundlesFolderPath = configurationBuildDir
    .stringByAppendingPathComponent("LaunchKitCachedBundles" as String)
let cachedBundlesFolderUrl = NSURL(fileURLWithPath: cachedBundlesFolderPath)

let appResourcesFolderPath = (targetBuildDir.stringByAppendingPathComponent(appExecutableDir as String) as NSString)
    .stringByAppendingPathComponent("LaunchKitRemoteResources" as String)
let appResourcesFolderUrl = NSURL(fileURLWithPath: appResourcesFolderPath)

// Include helper functions inline (scripts can't use support files) ///////////////////////////////////////////////

func prettyJsonStringFromObject(object: AnyObject) -> NSString {
    let jsonPrintStream = NSOutputStream.outputStreamToMemory()
    jsonPrintStream.open()
    var jsonError: NSError?
    NSJSONSerialization.writeJSONObject(object, toStream: jsonPrintStream, options: .PrettyPrinted, error: &jsonError)
    jsonPrintStream.close()
    let jsonOutString = NSString(data: jsonPrintStream.propertyForKey(NSStreamDataWrittenToMemoryStreamKey) as! NSData, encoding: NSUTF8StringEncoding)!
    return jsonOutString
}

func urlEncoded(str:String) -> String {
    return str.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
}

func retrieveRemoteBundlesManifest(apiToken: String, _ completion: ((bundles: [[NSObject: AnyObject]], error: NSError?) -> Void)?) {
    //print("Retrieving LaunchKit Remote Bundles Manifest...")
    let query = urlEncoded("token=\(apiToken)&bundle_id=\(appBundle)&version=\(appBundleVersion)&build=\(appBuildNumber)&debug_build=\(debugBuild)")
    let url = NSURL(string: "\(apiBaseUrlString)/v1/bundles?\(query)")!
    print("URL:")
    print("\(url)")
    let request = NSMutableURLRequest(URL: url)

    let semaphore = dispatch_semaphore_create(0)
    var data: NSData?
    var response: NSURLResponse?
    var error: NSError?
    let dataTask = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (maybeData, maybeResponse, maybeError) -> Void in
        data = maybeData
        response = maybeResponse
        error = maybeError
        dispatch_semaphore_signal(semaphore)
    })
    dataTask.resume()
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

    if let data = data {
        do {
            let jsonDict = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as! [NSObject:AnyObject]
            if verboseDebugging {
                print("JSON Response: \(prettyJsonStringFromObject(jsonDict))")
            }
            if let bundleInfos = jsonDict["bundles"] as? [[NSObject:AnyObject]] {
                completion?(bundles: bundleInfos, error: nil)
            } else {
                completion?(bundles: [], error: nil)
            }
        } catch {
            print("Invalid json returned. Check your api token and network connection (received \(data.length) bytes)")
            completion?(bundles: [], error: error as NSError)
        }
    } else {
        print("Got no data from remote bundles lookup, response: \(response?.description)")
        completion?(bundles: [], error: error)
    }
}

func directoryUrlForBundleName(name:String, version:String, parentUrl: NSURL = cachedBundlesFolderUrl) -> NSURL {
    let directoryUrl = parentUrl
        .URLByAppendingPathComponent(name, isDirectory:true)
        .URLByAppendingPathComponent(version, isDirectory: true)
    return directoryUrl
}

func bundleAlreadyCached(name:String, version:String) -> Bool {
    let fileManager = NSFileManager.defaultManager()

    let bundleDir = directoryUrlForBundleName(name, version: version, parentUrl: cachedBundlesFolderUrl)
    let versionFolderExists = fileManager.fileExistsAtPath(bundleDir.path!)
    return versionFolderExists
}

func copyCachedBundleToAppBundle(name:String, version:String) {
    let fileManager = NSFileManager.defaultManager()
    let cachedBundleDir = directoryUrlForBundleName(name, version: version, parentUrl: cachedBundlesFolderUrl)
    let appBundleDir = directoryUrlForBundleName(name, version: version, parentUrl: appResourcesFolderUrl)

    let bundleNameDir = appBundleDir.URLByDeletingLastPathComponent!
    if fileManager.fileExistsAtPath(bundleNameDir.path!) {
        // Delete all version of this bundle (and then we'll copy a new fresh version over)
        if verboseDebugging {
            print("Deleting bundle \(name) in app bundle dir...")
        }
        do {
            try fileManager.removeItemAtURL(bundleNameDir)
        } catch {
            print("Could not delete existing bundle \(name) in app bundle dir: \(error as NSError)")
        }

    }
    // Make dir structure for [app]/LaunchKitRemoteResources/[bundle]/[version]
    if !fileManager.fileExistsAtPath(appBundleDir.path!) {
        do {
            try fileManager.createDirectoryAtPath(appBundleDir.path!, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Could not create app bundle dir: \(error as NSError)")
        }
    }
    // Copy contents of [cached]/[bundle]/[version]/* to [app]/LaunchKitRemoteResources/[bundle]/[version]/
    do {
        let sourceItemUrls = try fileManager.contentsOfDirectoryAtURL(cachedBundleDir, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles) as [NSURL]
        for sourceItemUrl in sourceItemUrls {
            do {
                try fileManager.copyItemAtURL(sourceItemUrl, toURL: appBundleDir.URLByAppendingPathComponent(sourceItemUrl.lastPathComponent!))
            } catch {
                print("Could not copy cached bundle \(name)'s file \(sourceItemUrl.lastPathComponent!) to app bundle dir: \((error as NSError).userInfo)")
            }
        }
    } catch {

    }
}

func saveDataAtUrl(url:NSURL, toFileUrl fileUrl:NSURL) -> Bool {
    let fileManager = NSFileManager.defaultManager()

    let request = NSMutableURLRequest(URL: url)

    let semaphore = dispatch_semaphore_create(0)
    var data: NSData?
    var response: NSURLResponse?
    var error: NSError?
    let dataTask = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { (maybeData, maybeResponse, maybeError) -> Void in
        data = maybeData
        response = maybeResponse
        error = maybeError
        dispatch_semaphore_signal(semaphore)
    })
    dataTask.resume()
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

    if let data = data {
        if let folderUrl = fileUrl.URLByDeletingLastPathComponent {
            // Ensure that the parent folder for this fileurl is already created
            do {
                try fileManager.createDirectoryAtURL(folderUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Couldn't create directory at \(folderUrl), error: \(error as NSError)")
                return false
            }

            // Remove an older file, if it exists
            if fileManager.fileExistsAtPath(fileUrl.path!) {
                do {
                    try fileManager.removeItemAtPath(fileUrl.path!)
                } catch {
                    print("Couldn't delete existing file at url: \(fileUrl)")
                }
            }

            data.writeToURL(fileUrl, atomically: false)

            if let fileExtension = fileUrl.pathExtension where fileExtension == "zip" {
                // We just saved a zip file, so unzip it
                let task = NSTask()
                task.launchPath = "/usr/bin/unzip"
                // Rather than using the "-d [extractiondir] option, set the current dir path, so
                // the file will extract in the same place as where we downloaded it
                task.currentDirectoryPath = folderUrl.path!
                task.arguments = [
                    "-o", // Overwrite files without prompting
                    "-q", // Quiet mode
                    fileUrl.path!, // Path to the .zip file
                ]
                task.launch()
                task.waitUntilExit()

                // Now delete the original fileUrl
                do {
                    try fileManager.removeItemAtURL(fileUrl)
                } catch {
                    print("Couldn't remove the zipped file after extracting it: \(error as NSError)")
                }
            }

            if verboseDebugging {
                print("Saved to: \(fileUrl.URLByDeletingLastPathComponent!)")
            }
        }
        return true
    } else {
        print("Received no data from remote url. Response: \(response), error: \(error)")
        return false
    }
}

/////////////////////////////////////////////////////////////////

retrieveRemoteBundlesManifest(apiToken, { (bundles, error) -> Void in
    if let error = error {
        // Probably some sort of networking issue, but don't fail the script. 
        // Developer could be on a plane building their app, for example.
        print("Error caching LaunchKit remote resources due to error: \(error.domain) - \(error.code) - \(error.localizedDescription).")
        print("Verify that your network connection is established and working. Skipping for this build.")
        exit(EXIT_SUCCESS)
    } else {
        print("Caching LaunchKit remote resources to app bundle (for super-fast loads)")
        for bundle in bundles {
            let name = bundle["name"] as! String
            let url = NSURL(string: bundle["url"] as! String)!
            let version = bundle["version"] as! String

            var available = bundleAlreadyCached(name, version: version)
            if verboseDebugging {
                let cachedString = available ? " (cached)" : " (needs download)"
                print(" => \(name): \(url.absoluteString)\(cachedString)")
            }

            if !available {
                if verboseDebugging {
                    print("Downloading \(name)...")
                }
                let fileDownloadUrl = directoryUrlForBundleName(name, version: version, parentUrl: cachedBundlesFolderUrl)
                    .URLByAppendingPathComponent(url.lastPathComponent!, isDirectory: false)
                available = saveDataAtUrl(url, toFileUrl: fileDownloadUrl)
            }
            if available {
                copyCachedBundleToAppBundle(name, version: version)
            }
        }
        // TODO: Perhaps save a dictionary of the remote UI maps to the app bundle too,
        // so a mapping is available on the first-time launch of the app
        exit(EXIT_SUCCESS)
    }
})
//print(NSProcessInfo.processInfo().environment)
