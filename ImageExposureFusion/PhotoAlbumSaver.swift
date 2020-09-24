//
//  PhotoAlbumSaver.swift
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//

import Foundation
import Photos
import UIKit
class PhotoAlbumSaver {

    static let albumName = "Flashpod"
    static let sharedInstance = PhotoAlbumSaver()

    var assetCollection: PHAssetCollection!

    init() {

        func fetchAssetCollectionForAlbum() -> PHAssetCollection! {

            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", PhotoAlbumSaver.albumName)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

            if let firstObject: AnyObject = collection.firstObject {
                return collection.firstObject as! PHAssetCollection
            }

            return nil
        }

        if let assetCollection = fetchAssetCollectionForAlbum() {
            self.assetCollection = assetCollection
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: PhotoAlbumSaver.albumName)
        }) { success, _ in
            if success {
                self.assetCollection = fetchAssetCollectionForAlbum()
            }
        }
    }

    func saveImage(image: UIImage) {
        if assetCollection == nil {
            return   // If there was an error upstream, skip the save.
        }
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            let assetPlaceholder = assetChangeRequest.placeholderForCreatedAsset
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
            albumChangeRequest?.addAssets([assetPlaceholder] as NSFastEnumeration)
        }, completionHandler: nil)
    }

    func savePhoto(photo: AVCapturePhoto) {
        if assetCollection == nil {
            return   // If there was an error upstream, skip the save.
        }
        PHPhotoLibrary.shared().performChanges({
            let assetChangeRequest = PHAssetCreationRequest.forAsset()
            let assetPlaceholder = assetChangeRequest.addResource(with: .photo, data: photo.fileDataRepresentation()!, options: nil)
            //let albumChangeRequest = PHAssetCollectionChangeRequest(for: self.assetCollection)
            //albumChangeRequest?.addAssets([assetPlaceholder] as NSFastEnumeration)
        }, completionHandler: nil)
    }


}
