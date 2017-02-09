//
//  ViewController.swift
//  driverquality
//
//  Created by Jesper Bränn on 2017-01-23.
//  Copyright © 2017 Jesper Bränn. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreMotion

protocol JSONRepresentable {
    var JSONRepresentation: Any { get }
}

protocol JSONSerializable: JSONRepresentable {}

extension JSONSerializable {
    var JSONRepresentation: Any {
        var representation = [String: Any]()
        
        for case let (label?, value) in Mirror(reflecting: self).children {
            
            switch value {
                
            case let value as Dictionary<String, Any>:
                representation[label] = value as AnyObject
                
            case let value as Array<Any>:
                if let val = value as? [JSONSerializable] {
                    representation[label] = val.map({ $0.JSONRepresentation as AnyObject }) as AnyObject
                } else {
                    representation[label] = value as AnyObject
                }
                
            case let value:
                representation[label] = value as AnyObject
                
            default:
                // Ignore any unserializable properties
                break
            }
        }
        return representation as Any
    }
}

extension JSONSerializable {
    func toJSON() -> String? {
        let representation = JSONRepresentation
        
        guard JSONSerialization.isValidJSONObject(representation) else {
            print("Invalid JSON Representation")
            return nil
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: representation, options: [])
            
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

struct SensorData : JSONSerializable {
    var longitude: Double
    var latitude: Double

    var accelerometerX: Double
    var accelerometerY: Double
    var accelerometerZ: Double

    var gyroscopeX: Double
    var gyroscopeY: Double
    var gyroscopeZ: Double

    var magnetometerX: Double
    var magnetometerY: Double
    var magnetometerZ: Double

    var roll: Double
    var pitch: Double
    var yaw: Double
    
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double

    var gravityX: Double
    var gravityY: Double
    var gravityZ: Double
    
    var userAccelerationX: Double
    var userAccelerationY: Double
    var userAccelerationZ: Double

    var magneticFieldX: Double
    var magneticFieldY: Double
    var magneticFieldZ: Double

}

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var scrollView : UIScrollView!
    @IBOutlet weak var map : MKMapView!

    @IBOutlet weak var gps : UILabel!
    @IBOutlet weak var accelerometer : UILabel!
    @IBOutlet weak var gyroscope : UILabel!
    @IBOutlet weak var magnetometer : UILabel!
    @IBOutlet weak var euler : UILabel!
    @IBOutlet weak var rotation : UILabel!
    @IBOutlet weak var gravity : UILabel!
    @IBOutlet weak var userAcceleration : UILabel!
    @IBOutlet weak var magneticField : UILabel!

    let manager = CMMotionManager()
    var locationManager: CLLocationManager!
    var lastUpdateMap : Double = 0.0
    var lastCoordinatesMap : CLLocationCoordinate2D!
    var sensorData = SensorData(longitude: 0, latitude: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 0, gyroscopeX: 0, gyroscopeY: 0, gyroscopeZ: 0, magnetometerX: 0, magnetometerY: 0, magnetometerZ: 0, roll: 0, pitch: 0, yaw: 0, rotationX: 0, rotationY: 0, rotationZ: 0, gravityX: 0, gravityY: 0, gravityZ: 0, userAccelerationX: 0, userAccelerationY: 0, userAccelerationZ: 0, magneticFieldX: 0, magneticFieldY: 0, magneticFieldZ: 0)
    
    var allSensorData: [SensorData] = []
    weak var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startButton.layer.borderColor = UIColor.blue.cgColor
        
        
        // Do any additional setup after loading the view, typically from a nib.
        // Ask for Authorisation from the User.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        map.delegate = self
        
        // For use in foreground
        locationManager.requestWhenInUseAuthorization()
        // For use in background
        locationManager.requestAlwaysAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else{
            print("Not allowed to GPS")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func startCollecting(_ sender: UIButton) {
        print("Press")
        
        map.delegate = self
        map.mapType = .standard
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        if let coor = map.userLocation.location?.coordinate{
            map.setCenter(coor, animated: true)
        }
        
        if manager.isDeviceMotionActive {
            print("Stop")
            locationManager.stopUpdatingLocation()
            startButton.setTitle("Start", for: .normal)
            manager.stopGyroUpdates()
            manager.stopAccelerometerUpdates()
            manager.stopMagnetometerUpdates()
            manager.stopDeviceMotionUpdates()
            gps.text = ""
            accelerometer.text = ""
            gyroscope.text = ""
            magnetometer.text = ""
            euler.text = ""
            rotation.text = ""
            gravity.text = ""
            userAcceleration.text = ""
            magneticField.text = ""
            stopTimer()
            saveData()
        } else {
            startButton.setTitle("Stop", for: .normal)
            locationManager.startUpdatingLocation()
            startTimer()
            if manager.isGyroAvailable {
                print("Gyro available!")
                manager.gyroUpdateInterval = 0.1
                manager.startGyroUpdates(to: .main) {
                    [weak self] (data: CMGyroData?, error: Error?) in
                    OperationQueue.main.addOperation {
                        self?.gyroscope.text = String(format: "%.2f", data!.rotationRate.x) + ", " + String(format: "%.2f", data!.rotationRate.y) + ", " + String(format: "%.2f", data!.rotationRate.z)
                        self?.sensorData.gyroscopeX = data!.rotationRate.x
                        self?.sensorData.gyroscopeY = data!.rotationRate.y
                        self?.sensorData.gyroscopeZ = data!.rotationRate.z
                    }
                }
            }

            if manager.isAccelerometerAvailable {
                print("Accelerometer available!")
                manager.accelerometerUpdateInterval = 0.1
                manager.startAccelerometerUpdates(to: OperationQueue.main) {
                    [weak self] (data: CMAccelerometerData?, error: Error?) in
                    OperationQueue.main.addOperation {
                        self?.accelerometer.text = String(format: "%.2f", data!.acceleration.x) + ", " + String(format: "%.2f", data!.acceleration.y) + ", " + String(format: "%.2f", data!.acceleration.z)
                        self?.sensorData.accelerometerX = data!.acceleration.x
                        self?.sensorData.accelerometerY = data!.acceleration.y
                        self?.sensorData.accelerometerZ = data!.acceleration.z

                    }
                }
            }
            
            if manager.isMagnetometerAvailable {
                print("Magnetometer available!")
                manager.magnetometerUpdateInterval = 0.1
                manager.showsDeviceMovementDisplay = true
                manager.startMagnetometerUpdates(to: OperationQueue.main) {
                    [weak self] (data: CMMagnetometerData?, error: Error?) in
                    OperationQueue.main.addOperation {
                        self?.magnetometer.text = String(format: "%.2f", data!.magneticField.x) + ", " + String(format: "%.2f", data!.magneticField.y) + ", " + String(format: "%.2f", data!.magneticField.z)
                        
                        self?.sensorData.magnetometerX = data!.magneticField.x
                        self?.sensorData.magnetometerY = data!.magneticField.y
                        self?.sensorData.magnetometerZ = data!.magneticField.z
                    }
                }
            }
            
            if manager.isDeviceMotionAvailable {
                print("Device motion available!")
                manager.deviceMotionUpdateInterval = 0.1
                manager.startDeviceMotionUpdates(to: OperationQueue.main) {
                    [weak self] (data: CMDeviceMotion?, error: Error?) in
                    OperationQueue.main.addOperation {
                        self?.euler.text = String(format: "%.2f", data!.attitude.roll) + ", " + String(format: "%.2f", data!.attitude.pitch) + ", " + String(format: "%.2f", data!.attitude.yaw)
                        
                        self?.rotation.text = String(format: "%.2f", data!.rotationRate.x) + ", " + String(format: "%.2f", data!.rotationRate.y) + ", " + String(format: "%.2f", data!.rotationRate.z)

                        self?.gravity.text = String(format: "%.2f", data!.gravity.x) + ", " + String(format: "%.2f", data!.gravity.y) + ", " + String(format: "%.2f", data!.gravity.z)

                        self?.userAcceleration.text = String(format: "%.2f", data!.userAcceleration.x) + ", " + String(format: "%.2f", data!.userAcceleration.y) + ", " + String(format: "%.2f", data!.userAcceleration.z)

                        self?.magneticField.text = String(format: "%.2f", data!.magneticField.field.x) + ", " + String(format: "%.2f", data!.magneticField.field.y) + ", " + String(format: "%.2f", data!.magneticField.field.z)
                        
                        
                        self?.sensorData.roll = data!.attitude.roll
                        self?.sensorData.pitch = data!.attitude.pitch
                        self?.sensorData.yaw = data!.attitude.yaw

                        self?.sensorData.rotationX = data!.rotationRate.x
                        self?.sensorData.rotationY = data!.rotationRate.y
                        self?.sensorData.rotationZ = data!.rotationRate.z
                        
                        self?.sensorData.gravityX = data!.gravity.x
                        self?.sensorData.gravityY = data!.gravity.y
                        self?.sensorData.gravityZ = data!.gravity.z

                        self?.sensorData.userAccelerationX = data!.userAcceleration.x
                        self?.sensorData.userAccelerationY = data!.userAcceleration.y
                        self?.sensorData.userAccelerationZ = data!.userAcceleration.z

                        self?.sensorData.magneticFieldX = data!.magneticField.field.x
                        self?.sensorData.magneticFieldY = data!.magneticField.field.y
                        self?.sensorData.magneticFieldZ = data!.magneticField.field.z
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        
        centerMap(locValue)
    }
    
    func currentTime() -> String {
        // get the current date and time
        let currentDateTime = Date()
        
        // initialize the date formatter and set the style
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .long
        
        // get the date time String from the date object
        return formatter.string(from: currentDateTime) // October 8, 2016 at 10:48:53 PM
    }
    
    func centerMap(_ center:CLLocationCoordinate2D){
        self.gps.text = "(" + String(format: "%.6f", center.latitude) + "), (" + String(format: "%.6f", center.longitude) + ")"
        
        let spanX = 0.007
        let spanY = 0.007
        
        let newRegion = MKCoordinateRegion(center:center , span: MKCoordinateSpanMake(spanX, spanY))
        map.setRegion(newRegion, animated: true)
        
        
//        let annotation = MKPointAnnotation()
//        annotation.coordinate = center
//        annotation.title = self.currentTime()
//        map.addAnnotation(annotation)

        sensorData.latitude = center.latitude
        sensorData.longitude = center.longitude
        
        if Date().timeIntervalSince1970 - lastUpdateMap > 1 {
            if lastCoordinatesMap != nil {
                var coordinates = [lastCoordinatesMap!, center]
                let polyline = MKPolyline(coordinates: &coordinates, count: 2)
                map.add(polyline)
            }
            
            lastCoordinatesMap = center
            lastUpdateMap = Date().timeIntervalSince1970
        }
    }
    
    // Callback to actually add PolyLine to map
    func mapView(_ mapView: MKMapView!, rendererFor overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            var pr = MKPolylineRenderer(overlay: overlay)
            pr.strokeColor = UIColor.red.withAlphaComponent(0.5)
            pr.lineWidth = 5
            return pr
        }
        
        return nil
    }
    
    func saveData() {
        var sensorDataJSON = allSensorData.map({
            (value: SensorData) -> String in
            return value.toJSON()!
        })
        let sensorDataAsString = "[" + sensorDataJSON.joined(separator: ",") + "]"
        print(sensorDataAsString)
    }
    
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.allSensorData.append((self?.sensorData)!)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    deinit {
        stopTimer()
    }
}

