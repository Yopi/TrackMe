//
//  ViewController.swift
//  driverquality
//
//  Created by Jesper Bränn on 2017-01-23.
//  Copyright © 2017 Jesper Bränn. All rights reserved.
//

import UIKit
import MapKit
import AVKit
import AVFoundation
import CoreLocation
import CoreMotion
import Foundation

struct AllSensorData {
    var phone_udid: String
    var name: String
    var time: Date
    var smooth: Int
    var data: [SensorData]
}

struct SensorData {
    var time: Date
    var phone_udid: String
    
    var longitude: Double
    var latitude: Double
    var speed: Double

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

    @IBOutlet weak var smoothSwitch: UISwitch!
    @IBOutlet weak var gpsLabel : UILabel!
    @IBOutlet weak var speedLabel : UILabel!

    @IBOutlet weak var accelerometerLabel : UILabel!
    @IBOutlet weak var gyroscopeLabel : UILabel!
    @IBOutlet weak var magnetometerLabel : UILabel!
    @IBOutlet weak var eulerLabel : UILabel!
    @IBOutlet weak var rotationLabel : UILabel!
    @IBOutlet weak var gravityLabel : UILabel!
    @IBOutlet weak var userAccelerationLabel : UILabel!
    @IBOutlet weak var magneticFieldLabel : UILabel!
    @IBOutlet weak var runningTimeLabel : UILabel!
    @IBOutlet weak var sizeOfDataLabel : UILabel!

    let manager = CMMotionManager()
    var locationManager: CLLocationManager!
    var lastUpdateMap : Double = 0.0
    var lastCoordinatesMap : CLLocationCoordinate2D!
    var sensorData = SensorData(time: Date.init(), phone_udid: (UIDevice.current.identifierForVendor?.uuidString)!, longitude: 0, latitude: 0, speed: 0, accelerometerX: 0, accelerometerY: 0, accelerometerZ: 0, gyroscopeX: 0, gyroscopeY: 0, gyroscopeZ: 0, magnetometerX: 0, magnetometerY: 0, magnetometerZ: 0, roll: 0, pitch: 0, yaw: 0, rotationX: 0, rotationY: 0, rotationZ: 0, gravityX: 0, gravityY: 0, gravityZ: 0, userAccelerationX: 0, userAccelerationY: 0, userAccelerationZ: 0, magneticFieldX: 0, magneticFieldY: 0, magneticFieldZ: 0)
    
    var allSensorData = AllSensorData(phone_udid: (UIDevice.current.identifierForVendor?.uuidString)!, name: "", time: Date.init(), smooth: 1, data: [])
    weak var timer: Timer?
    var running : Bool = false
    var startTime : Date = Date.init()
    var player: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startButton.layer.borderColor = UIColor.blue.cgColor
        
        
        // Do any additional setup after loading the view, typically from a nib.
        // Ask for Authorisation from the User.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        map.delegate = self
        
        // For use in foreground
        // For use in background
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
      
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else{
            print("Not allowed to GPS")
        }
        
        let url = Bundle.main.url(forResource: "silence", withExtension: "mp3")!
        do {
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else { return }
            
            let audioSession = AVAudioSession.sharedInstance()
            try!audioSession.setCategory(AVAudioSessionCategoryPlayback, with: AVAudioSessionCategoryOptions.mixWithOthers)
            
            player.prepareToPlay()
            player.volume = 1
            player.numberOfLoops = -1;
          print("Playing audio")
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let name = UserDefaults.standard.string(forKey: "name")
        if !(name != nil) {
            let alert = UIAlertController(title: "Name", message: "To tag your data a name is helpful", preferredStyle: UIAlertControllerStyle.alert)
            
            let saveAction = UIAlertAction(title: "Save", style: .default) { action in
                if let textField = alert.textFields?[0], let text = textField.text {
                    UserDefaults.standard.set(text, forKey: "name")
                } else {
                    // Didn't get text
                }
            }
            
            alert.addTextField(configurationHandler: {(textField: UITextField!) in
                textField.layer.borderWidth = 0
            })
            
            alert.addAction(saveAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func startCollecting(_ sender: UIButton) {
        print("Press")
        let name = UserDefaults.standard.string(forKey: "name")
        allSensorData.name = name!
        allSensorData.time = Date.init()
        
        map.delegate = self
        map.mapType = .standard
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        if let coor = map.userLocation.location?.coordinate{
            map.setCenter(coor, animated: true)
        }
        
        if running {
            print("Stop")
            stopTimer()
            manager.stopGyroUpdates()
            manager.stopAccelerometerUpdates()
            manager.stopMagnetometerUpdates()
            manager.stopDeviceMotionUpdates()
            locationManager.stopUpdatingLocation()

            gpsLabel.text = ""
            accelerometerLabel.text = ""
            gyroscopeLabel.text = ""
            magnetometerLabel.text = ""
            eulerLabel.text = ""
            rotationLabel.text = ""
            gravityLabel.text = ""
            userAccelerationLabel.text = ""
            magneticFieldLabel.text = ""

            // Async JSON encode
            DispatchQueue.global().async {
                self.saveData()
            }
            
            running = false
            self.runningTimeLabel.text = "Running: " + String(format: "%.2f", Date.init().timeIntervalSince(startTime)) + "s"
            startButton.setTitle("Start", for: .normal)

            self.player?.stop()
        } else {
            running = true
            allSensorData.data = []
            startButton.setTitle("Stop", for: .normal)
            locationManager.startUpdatingLocation()
            startTimer()
            startTime = Date.init()
            self.runningTimeLabel.text = ""
            self.sizeOfDataLabel.text = ""

            self.player?.play()

            if manager.isGyroAvailable {
                print("Gyro available!")
                manager.gyroUpdateInterval = 0.1
                manager.startGyroUpdates()
            }

            if manager.isAccelerometerAvailable {
                print("Accelerometer available!")
                manager.accelerometerUpdateInterval = 0.1
                manager.startAccelerometerUpdates()
            }
            
            if manager.isMagnetometerAvailable {
                print("Magnetometer available!")
                manager.magnetometerUpdateInterval = 0.1
                manager.showsDeviceMovementDisplay = true
                manager.startMagnetometerUpdates()
            }
            
            if manager.isDeviceMotionAvailable {
                print("Device motion available!")
                manager.deviceMotionUpdateInterval = 0.1
                manager.startDeviceMotionUpdates()
            }
        }
    }
    
    @IBAction func onAllAccessory(sender: UISwitch) {
        if smoothSwitch.isOn {
            self.allSensorData.smooth = 1
        } else {
            self.allSensorData.smooth = 0
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        self.speedLabel.text = String(format: "%.2f", manager.location!.speed) + " m/s"
        self.sensorData.speed = manager.location!.speed

        centerMap(locValue)
    }

    func centerMap(_ center:CLLocationCoordinate2D){
        self.gpsLabel.text = "(" + String(format: "%.6f", center.latitude) + "), (" + String(format: "%.6f", center.longitude) + ")"
        
        let spanX = 0.007
        let spanY = 0.007
        
        let newRegion = MKCoordinateRegion(center:center , span: MKCoordinateSpanMake(spanX, spanY))
        map.setRegion(newRegion, animated: true)
  
        sensorData.latitude = center.latitude
        sensorData.longitude = center.longitude
        print(String(sensorData.latitude) + ", " + String(sensorData.longitude))
        
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
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if (overlay is MKPolyline) {
            let pr = MKPolylineRenderer(overlay: overlay)
            pr.strokeColor = UIColor.red.withAlphaComponent(0.5)
            pr.lineWidth = 5
            return pr
        }
        
        return MKPolylineRenderer()
    }
    
    func saveData() {
        do {
            let dictionary: WrappedDictionary = try wrap(self.allSensorData)
            let sensorDataAsString = String(describing: dictionary)
            print("Bytes: " + String(describing: sensorDataAsString.lengthOfBytes(using: String.Encoding.utf8)))
            print("KiloBytes: " + String(describing: sensorDataAsString.lengthOfBytes(using: String.Encoding.utf8)/1024))
            print("MegaBytes: " + String(describing: sensorDataAsString.lengthOfBytes(using: String.Encoding.utf8)/1048576))
            self.sizeOfDataLabel.text = String(describing: sensorDataAsString.lengthOfBytes(using: String.Encoding.utf8)/1024) + "KB"

            let json = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            _ = String(data: json, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
            var request = URLRequest(url: URL(string: "http://sensor.jesper.im/save")!)
            // var request = URLRequest(url: URL(string: "http://10.0.5.243:9292/save")!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
            URLSession.shared.dataTask(with:request, completionHandler: {(data, response, error) in
                print(response!)
                if error != nil {
                    print(error!)
                } else {
                    do {
                        guard let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any] else { return }
                        
                        guard let errors = json?["errors"] as? [[String: Any]] else { return }
                        if errors.count > 0 {
                            print(errors)
                            // show error
                            return
                        } else {
                            print("successful")
                            // show confirmation
                        }
                    }
                }
            }).resume()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func readSensoryData() {
      print("Reading sensor data")
      if self.manager.deviceMotion != nil {
        if self.manager.isGyroActive {
            let gyroData: CMGyroData! = self.manager.gyroData
            self.sensorData.gyroscopeX = gyroData.rotationRate.x
            self.sensorData.gyroscopeY = gyroData.rotationRate.y
            self.sensorData.gyroscopeZ = gyroData.rotationRate.z
        }

        if self.manager.isAccelerometerActive {
            let accelerometerData: CMAccelerometerData! = self.manager.accelerometerData
            self.sensorData.accelerometerX = accelerometerData.acceleration.x
            self.sensorData.accelerometerY = accelerometerData.acceleration.y
            self.sensorData.accelerometerZ = accelerometerData.acceleration.z
        }

        if self.manager.isMagnetometerActive {
            let magnetometerData: CMMagnetometerData! = self.manager.magnetometerData
            self.sensorData.magnetometerX = magnetometerData.magneticField.x
            self.sensorData.magnetometerY = magnetometerData.magneticField.y
            self.sensorData.magnetometerZ = magnetometerData.magneticField.z
        }

        if self.manager.isDeviceMotionActive {
            let deviceMotion: CMDeviceMotion! = self.manager.deviceMotion
            self.sensorData.roll = deviceMotion.attitude.roll
            self.sensorData.pitch = deviceMotion.attitude.pitch
            self.sensorData.yaw = deviceMotion.attitude.yaw
            self.sensorData.rotationX = deviceMotion.rotationRate.x
            self.sensorData.rotationY = deviceMotion.rotationRate.y
            self.sensorData.rotationZ = deviceMotion.rotationRate.z
            self.sensorData.gravityX = deviceMotion.gravity.x
            self.sensorData.gravityY = deviceMotion.gravity.y
            self.sensorData.gravityZ = deviceMotion.gravity.z
            self.sensorData.userAccelerationX = deviceMotion.userAcceleration.x
            self.sensorData.userAccelerationY = deviceMotion.userAcceleration.y
            self.sensorData.userAccelerationZ = deviceMotion.userAcceleration.z
            self.sensorData.magneticFieldX = deviceMotion.magneticField.field.x
            self.sensorData.magneticFieldY = deviceMotion.magneticField.field.y
            self.sensorData.magneticFieldZ = deviceMotion.magneticField.field.z
        }
        
        self.gyroscopeLabel.text = String(format: "%.2f", self.sensorData.gyroscopeX) + ", " +
            String(format: "%.2f", self.sensorData.gyroscopeY) + ", " +
            String(format: "%.2f", self.sensorData.gyroscopeZ)
        self.accelerometerLabel.text = String(format: "%.2f", self.sensorData.accelerometerX) + ", " +
            String(format: "%.2f", self.sensorData.accelerometerY) + ", " +
            String(format: "%.2f", self.sensorData.accelerometerZ)
        self.magnetometerLabel.text = String(format: "%.2f", self.sensorData.magnetometerX) + ", " +
            String(format: "%.2f", self.sensorData.magnetometerY) + ", " +
            String(format: "%.2f", self.sensorData.magnetometerZ)
        self.eulerLabel.text = String(format: "%.2f", self.sensorData.roll) + ", " +
            String(format: "%.2f", self.sensorData.pitch) + ", " +
            String(format: "%.2f", self.sensorData.yaw)
        self.rotationLabel.text = String(format: "%.2f", self.sensorData.rotationX) + ", " +
            String(format: "%.2f", self.sensorData.rotationY) + ", " +
            String(format: "%.2f", self.sensorData.rotationZ)
        self.gravityLabel.text = String(format: "%.2f", self.sensorData.gravityX) + ", " +
            String(format: "%.2f", self.sensorData.gravityY) + ", " +
            String(format: "%.2f", self.sensorData.gravityZ)
        self.userAccelerationLabel.text = String(format: "%.2f", self.sensorData.userAccelerationX) + ", " +
            String(format: "%.2f", self.sensorData.userAccelerationY) + ", " +
            String(format: "%.2f", self.sensorData.userAccelerationZ)
        self.magneticFieldLabel.text = String(format: "%.2f", self.sensorData.magneticFieldX) + ", " +
            String(format: "%.2f", self.sensorData.magneticFieldY) + ", " +
            String(format: "%.2f", self.sensorData.magneticFieldZ)
      }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.sensorData.time = Date.init()
            self?.readSensoryData()
            self?.allSensorData.data.append((self?.sensorData)!)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    deinit {
        stopTimer()
    }
}

