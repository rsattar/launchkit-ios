#!/usr/bin/env xcrun swift
import Foundation

// EXIT IF NOT RUNNING WITH PARAM
if Process.arguments.count <= 1 {
    println("No apiToken supplied. Supply apiToken as first parameter. Get an api token at https://launchkit.io/my-apps")
    exit(EXIT_FAILURE)
}

let apiToken = Process.arguments[1]
let useLocalServer: Bool
if find(Process.arguments, "-local") != nil {
    useLocalServer = true
} else {
    useLocalServer = false
}
let verboseDebugging: Bool
if find(Process.arguments, "-verbose") != nil {
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

let env = NSProcessInfo.processInfo().environment as! [String:NSString]

let targetBuildDir: NSString
let appExecutableDir: NSString
let infoPlistPath: String
if let buildDir = env["TARGET_BUILD_DIR"], let executableDir = env["EXECUTABLE_FOLDER_PATH"], let plistPath = env["INFOPLIST_PATH"] {
    targetBuildDir = buildDir
    appExecutableDir = executableDir
    infoPlistPath = targetBuildDir.stringByAppendingPathComponent(plistPath as String);
} else {
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
    println("Debug build: \(debugBuild), local server: \(useLocalServer)")
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
    println("Bundle: \(appBundle)")
    println("Version: \(appBundleVersion)")
    println("Build: \(appBuildNumber)")
    println("App OS Version: \(appOSVersion)")
    println("hardwareModel: \(hardwareModel)")
}

let cachedBundlesFolderPath = targetBuildDir
    .stringByAppendingPathComponent("LaunchKitCachedBundles" as String)
let cachedBundlesFolderUrl = NSURL(fileURLWithPath: cachedBundlesFolderPath)!

let appResourcesFolderPath = targetBuildDir
    .stringByAppendingPathComponent(appExecutableDir as String)
    .stringByAppendingPathComponent("LaunchKitRemoteResources" as String)
let appResourcesFolderUrl = NSURL(fileURLWithPath: appResourcesFolderPath)!

// Include helper functions inline (scripts can't use support files) ///////////////////////////////////////////////

func prettyJsonStringFromObject(object: AnyObject) -> NSString {
    var jsonPrintStream = NSOutputStream.outputStreamToMemory()
    jsonPrintStream.open()
    var jsonError: NSError?
    NSJSONSerialization.writeJSONObject(object, toStream: jsonPrintStream, options: .PrettyPrinted, error: &jsonError)
    jsonPrintStream.close()
    let jsonOutString = NSString(data: jsonPrintStream.propertyForKey(NSStreamDataWrittenToMemoryStreamKey) as! NSData, encoding: NSUTF8StringEncoding)!
    return jsonOutString
}

func urlEncoded(str:String) -> String {
    return str.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
}

func retrieveRemoteBundlesManifest(apiToken: String, completion: ((bundles: [[NSObject: AnyObject]], error: NSError?) -> Void)?) {
    //println("Retrieving LaunchKit Remote Bundles Manifest...")

    let url = NSURL(string: "\(apiBaseUrlString)/v1/bundles?token=\(urlEncoded(apiToken))&bundle=\(urlEncoded(appBundle))&version=\(urlEncoded(appBundleVersion))&build=\(urlEncoded(appBuildNumber))&debug_build=\(debugBuild)")!
    var request = NSMutableURLRequest(URL: url)

    var response: NSURLResponse?
    var error: NSError?
    let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error)
    if data != nil {
        var jsonError: NSError?
        let jsonDict = NSJSONSerialization.JSONObjectWithData(data!, options: nil, error: &jsonError) as! [NSObject:AnyObject]
        if jsonError != nil {
            println("Invalid json returned. Check your api token and network connection (received \(data!.length) bytes)")
            completion?(bundles: [], error: jsonError)
        } else {
            if verboseDebugging {
                println("JSON Response: \(prettyJsonStringFromObject(jsonDict))")
            }
            if let bundleInfos = jsonDict["bundles"] as? [[NSObject:AnyObject]] {
                completion?(bundles: bundleInfos, error: nil)
            } else {
                completion?(bundles: [], error: nil)
            }
        }
    } else {
        println("Got no data from remote bundles lookup, response: \(response?.description)")
        completion?(bundles: [], error: error)
    }
}

func directoryUrlForBundleName(name:String, #version:String, parentUrl: NSURL = cachedBundlesFolderUrl) -> NSURL {
    let directoryUrl = parentUrl
        .URLByAppendingPathComponent(name, isDirectory:true)
        .URLByAppendingPathComponent(version, isDirectory: true)
    return directoryUrl
}

func bundleAlreadyCached(name:String, #version:String) -> Bool {
    let fileManager = NSFileManager.defaultManager()

    let bundleDir = directoryUrlForBundleName(name, version: version, parentUrl: cachedBundlesFolderUrl)
    let versionFolderExists = fileManager.fileExistsAtPath(bundleDir.path!)
    return versionFolderExists
}

func copyCachedBundleToAppBundle(name:String, #version:String) {
    let fileManager = NSFileManager.defaultManager()
    let cachedBundleDir = directoryUrlForBundleName(name, version: version, parentUrl: cachedBundlesFolderUrl)
    let appBundleDir = directoryUrlForBundleName(name, version: version, parentUrl: appResourcesFolderUrl)

    let bundleNameDir = appBundleDir.URLByDeletingLastPathComponent!
    if fileManager.fileExistsAtPath(bundleNameDir.path!) {
        // Delete all version of this bundle (and then we'll copy a new fresh version over)
        if verboseDebugging {
            println("Deleting bundle \(name) in app bundle dir...")
        }
        var deleteError:NSError?
        let deleted = fileManager.removeItemAtURL(bundleNameDir, error: &deleteError)
        if !deleted {
            println("Could not delete existing bundle \(name) in app bundle dir: \(deleteError!)")
        }
    }
    // Make dir structure for [app]/LaunchKitRemoteResources/[bundle]/[version]
    if !fileManager.fileExistsAtPath(appBundleDir.path!) {
        var appBundleDirCreateError:NSError?
        let dirCreated = fileManager.createDirectoryAtPath(appBundleDir.path!, withIntermediateDirectories: true, attributes: nil, error: &appBundleDirCreateError)
        if !dirCreated {
            println("Could not create app bundle dir: \(appBundleDirCreateError!)")
        }
    }
    // Copy contents of [cached]/[bundle]/[version]/* to [app]/LaunchKitRemoteResources/[bundle]/[version]/
    if let sourceItemUrls = fileManager.contentsOfDirectoryAtURL(cachedBundleDir, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles, error: nil) as? [NSURL] {
        for sourceItemUrl in sourceItemUrls {
            var copyError:NSError?
            let copied = fileManager.copyItemAtURL(sourceItemUrl, toURL: appBundleDir.URLByAppendingPathComponent(sourceItemUrl.lastPathComponent!), error: &copyError)
            if !copied {
                println("Could not copy cached bundle \(name)'s file \(sourceItemUrl.lastPathComponent!) to app bundle dir: \(copyError!.userInfo!)")
            }
        }
    }
}

func saveDataAtUrl(url:NSURL, toFileUrl fileUrl:NSURL) -> Bool {
    let fileManager = NSFileManager.defaultManager()

    var request = NSMutableURLRequest(URL: url)

    var response: NSURLResponse?
    var error: NSError?
    if let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error) {

        if let folderUrl = fileUrl.URLByDeletingLastPathComponent {
            // Ensure that the parent folder for this fileurl is already created
            var createDirError: NSError?
            fileManager.createDirectoryAtURL(folderUrl, withIntermediateDirectories: true, attributes: nil, error: &createDirError)
            if createDirError != nil {
                println("Couldn't create directory at \(folderUrl), error: \(error)")
                return false
            }

            // Remove an older file, if it exists
            if fileManager.fileExistsAtPath(fileUrl.path!) {
                var removeExistingFileError: NSError?
                fileManager.removeItemAtPath(fileUrl.path!, error: &removeExistingFileError)
                if removeExistingFileError != nil {
                    println("Couldn't delete existing file at url: \(fileUrl)")
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
                var removeZipFileError: NSError?
                fileManager.removeItemAtURL(fileUrl, error: &removeZipFileError)
                if removeZipFileError != nil {
                    println("Couldn't remove the zipped file after extracting it: \(removeZipFileError)")
                }
            }

            if verboseDebugging {
                println("Saved to: \(fileUrl.URLByDeletingLastPathComponent!)")
            }
        }
        return true

    } else {
        println("Received no data from remote url. Response: \(response), error: \(error)")
        return false
    }
}

/////////////////////////////////////////////////////////////////

retrieveRemoteBundlesManifest(apiToken, { (bundles, error) -> Void in
    if error != nil {
        println("Error retrieving remote resource info (for caching): \(error)")
        exit(EXIT_FAILURE)
    } else {
        println("Caching LaunchKit remote resources to app bundle (for super-fast loads)")
        for bundle in bundles {
            let name = bundle["name"] as! String
            let url = NSURL(string: bundle["url"] as! String)!
            let version = bundle["version"] as! String

            var available = bundleAlreadyCached(name, version: version)
            if verboseDebugging {
                let cachedString = available ? " (cached)" : " (needs download)"
                println(" => \(name): \(url.absoluteString!)\(cachedString)")
            }

            if !available {
                if verboseDebugging {
                    println("Downloading \(name)...")
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
//println(NSProcessInfo.processInfo().environment)
