import Foundation
import WidgetKit
import UIKit

public class WidgetImageCache: NSObject {
    public static let shared = WidgetImageCache()

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "WidgetImageCacheDownloadSession")
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var completion:(()->())?
    public func setCompletion(_ c:@escaping ()->() )  {
        completion = c
    }
    
    public func startThumbDownloadTaskIfNeeds(_ urlStr:String ) {
        if let url = URL(string: urlStr) {
            let cacheFile = cachePath(for: url)
            if !FileManager.default.fileExists(atPath: cacheFile!.absoluteString) {
                let task = urlSession.downloadTask(with: url)
                task.resume()
            }
        }
    }
}

// MARK: Cache Path
extension WidgetImageCache {
    private var cacheDirectory:URL {
        let cacheDir = try! FileManager.default.url(for: .cachesDirectory, in: .allDomainsMask, appropriateFor: nil, create: false)
        let fileDir = cacheDir.appendingPathComponent("WidgetImageCache")
        
        if !FileManager.default.fileExists(atPath: fileDir.absoluteString) {
            do {
                try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("failed to create directory:\(fileDir) error:\(error)")
            }
        }
        
        return fileDir
    }
    
    public func cachePath(for url:URL) -> URL? {
        let urlStr = url.absoluteString
        let filename = urlStr.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? urlStr
        
        return cacheDirectory.appendingPathComponent(filename, isDirectory: false)
    }
    
    public func cachePath(for path:String) -> String? {
        let url = URL(fileURLWithPath: path)
        return cachePath(for: url)?.path
    }
}

// MARK: URLSession Delegates
extension WidgetImageCache: URLSessionDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let url =  downloadTask.originalRequest?.url
        let path = cachePath(for: url!)
        
        if let image = UIImage(contentsOfFile: location.absoluteString) {
            
            let resizedImage = UIImage.resize(image: image, targetSize: CGSize(width: 100, height: 100))
            
            let jpegData = resizedImage.jpegData(compressionQuality: 0.8)
            try? jpegData?.write(to: path!)
        }
        
        //TODO: save multiple thumb size
        
        //save origin image?
        //try? FileManager.default.moveItem(at: location, to: path!)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        WidgetCenter.shared.reloadTimelines(ofKind: "org.tiny4.ladderfront.NewsWidget")

        if let c = completion {
            c()
        }
        
        completion = nil
    }
}


extension UIImage {
    class func resize(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        var newImage: UIImage?
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: rect)
        newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    class func scale(image: UIImage, by scale: CGFloat) -> UIImage? {
        let size = image.size
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIImage.resize(image: image, targetSize: scaledSize)
    }
}
