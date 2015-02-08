-- Measure temperature, humidity and post data to thingspeak.com
-- 2015 chk1, modified to work with Opensensemap
-- 2014 OK1CDJ, original version for Thingspeak
-- DHT11 code is from esp8266.com
---Sensor DHT11 is conntected to GPIO0
boxid = "54d726661b93e970075148bd"
sensorid_temp = "54d726661b93e970075148c0"
sensorid_hum = "54d726661b93e970075148bf"

pin = 3

Humidity = 0
HumidityDec=0
Temperature = 0
TemperatureDec=0
Checksum = 0
ChecksumTest=0

function getTemp()
     Humidity = 0
     HumidityDec=0
     Temperature = 0
     TemperatureDec=0
     Checksum = 0
     ChecksumTest=0
     
     --Data stream acquisition timing is critical. There's
     --barely enough speed to work with to make this happen.
     --Pre-allocate vars used in loop.
     
     bitStream = {}
     for j = 1, 40, 1 do
          bitStream[j]=0
     end
     bitlength=0
     
     gpio.mode(pin, gpio.OUTPUT)
     gpio.write(pin, gpio.LOW)
     tmr.delay(20000)
     --Use Markus Gritsch trick to speed up read/write on GPIO
     gpio_read=gpio.read
     gpio_write=gpio.write
     
     gpio.mode(pin, gpio.INPUT)
     
     --bus will always let up eventually, don't bother with timeout
     while (gpio_read(pin)==0 ) do end
     
     c=0
     while (gpio_read(pin)==1 and c<100) do c=c+1 end
     
     --bus will always let up eventually, don't bother with timeout
     while (gpio_read(pin)==0 ) do end
     
     c=0
     while (gpio_read(pin)==1 and c<100) do c=c+1 end
     
     --acquisition loop
     for j = 1, 40, 1 do
          while (gpio_read(pin)==1 and bitlength<10 ) do
               bitlength=bitlength+1
          end
          bitStream[j]=bitlength
          bitlength=0
          --bus will always let up eventually, don't bother with timeout
          while (gpio_read(pin)==0) do end
     end
     
     --DHT data acquired, process.
     
     for i = 1, 8, 1 do
          if (bitStream[i+0] > 2) then
               Humidity = Humidity+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+8] > 2) then
               HumidityDec = HumidityDec+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+16] > 2) then
               Temperature = Temperature+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+24] > 2) then
               TemperatureDec = TemperatureDec+2^(8-i)
          end
     end
     for i = 1, 8, 1 do
          if (bitStream[i+32] > 2) then
               Checksum = Checksum+2^(8-i)
          end
     end
     ChecksumTest=(Humidity+HumidityDec+Temperature+TemperatureDec) % 0xFF
     
     print ("Temperature: "..Temperature.."."..TemperatureDec)
     print ("Humidity: "..Humidity.."."..HumidityDec)
     print ("ChecksumReceived: "..Checksum)
     print ("ChecksumTest: "..ChecksumTest)
end

--- Get temp and send data to opensensemap
function sendData(boxid, sensorid, sensorval)
     -- conection to opensensemap
     print("Sending data to opensensemap")
     valuejson = "{\"value\": \"".. sensorval .."\"}"
     conn=net.createConnection(net.TCP, 0) 
     conn:on("receive", function(conn, payload) print(payload) end)
     -- opensensemap.org 128.176.146.243
     conn:connect(8000, '128.176.146.243') 
     conn:send("POST /boxes/".. boxid .."/".. sensorid .." HTTP/1.1\r\n") 
     conn:send("Host: opensensemap.org\r\n") 
     conn:send("Content-Type: application/json\r\n") 
     conn:send("Connection: close\r\n") 
     conn:send("Content-Length: ")
     conn:send(string.len(valuejson))
     conn:send("\r\n")
     conn:send("\r\n")
     conn:send(valuejson)
     conn:send("\r\n")
     conn:on("sent",function(conn)
                           print("Closing connection")
                           conn:close()
                       end)
     conn:on("disconnection", function(conn)
                           print("Got disconnection...")
  end)
end
-- send data every 60000 ms (60sek) to opensensemap api
tmr.alarm(2, 60000, 1, function() 
     getTemp()
     sendData(boxid, sensorid_temp, Temperature) 
     sendData(boxid, sensorid_hum, Humidity) 
end )
