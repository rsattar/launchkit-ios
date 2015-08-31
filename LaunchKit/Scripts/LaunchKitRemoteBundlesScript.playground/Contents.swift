#!/usr/bin/env xcrun swift
import Foundation

// EXIT IF NOT RUNNING WITH PARAM
if Process.arguments.count <= 1 {
    println("No apiToken supplied. Supply apiToken as first parameter. Get an api token at https://launchkit.io/my-apps")
    exit(EXIT_FAILURE)
}

let apiToken = Process.arguments[1]
var useLocalServer = false
if Process.arguments.count > 2 {
    if Process.arguments[2] == "-local" {
        useLocalServer = true
    }
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
println("Debug build: \(debugBuild), local server: \(useLocalServer)")


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
}

// TODO(Riz):
let appOSVersion: String = ""
let hardwareModel: String = ""

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

func retrieveRemoteBundlesManifest(apiToken: String, completion: ((bundles: [[NSObject: AnyObject]], error: NSError?) -> Void)?) {
    //println("Retrieving LaunchKit Remote Bundles Manifest...")

    let url = NSURL(string: "\(apiBaseUrlString)/v1/bundles?token=\(apiToken)&bundle=\(appBundle)&version=\(appBundleVersion)&build=\(appBuildNumber)&debug_build=\(debugBuild)")!
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
            //println("JSON Response: \(prettyJsonStringFromObject(jsonDict))")
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

            //println("Saved to: \(fileUrl.URLByDeletingLastPathComponent!)")
        }
        return true

    } else {
        println("Received no data from remote url. Response: \(response), error: \(error)")
        return false
    }
}

/////////////////////////////////////////////////////////////////
let launchKitResourcesFolderPath = targetBuildDir
    .stringByAppendingPathComponent(appExecutableDir as String)
    .stringByAppendingPathComponent("LaunchKitRemoteResources" as String)

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
            //println(" => \(name): \(url.absoluteString!)")

            let fileDownloadUrl = NSURL(fileURLWithPath: launchKitResourcesFolderPath)!
                .URLByAppendingPathComponent(name, isDirectory:true)
                .URLByAppendingPathComponent(version, isDirectory: true)
            .URLByAppendingPathComponent(url.lastPathComponent!, isDirectory: false)
            saveDataAtUrl(url, toFileUrl: fileDownloadUrl)
        }
        // TODO: Perhaps save a dictionary of the remote UI maps to the app bundle too, 
        // so a mapping is available on the first-time launch of the app
        exit(EXIT_SUCCESS)
    }
})
//println(NSProcessInfo.processInfo().environment)
