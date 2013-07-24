// Read data from MAX31855 chip on Adafruit breakout boards

//      pins:
//      imp 1 CLK
//      imp 2 CS
//      imp 5 UART
//      imp 7 UNASSIGNED
//      imp 8 CS
//      imp 9 DO
//Configure Pins
hardware.spi189.configure(MSB_FIRST | CLOCK_IDLE_LOW , 1000);
hardware.pin2.configure(DIGITAL_OUT); //chip select
hardware.pin8.configure(DIGITAL_OUT); //chip select
// Configure the UART port
local port0 = hardware.uart57;
port0.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);
// Output structure for sending temperature to server
local tempOut    = OutputPort("Sensor1 (F)", "number");
local tempOutStr = OutputPort("Sensor1 (F)", "string");
local tempOut2    = OutputPort("Sensor2 (F)", "number");
local tempOutStr2 = OutputPort("Sensor2 (F)", "string");
local temp32 = 0;
farenheit <- 0;
celcius <- 0;
trigger1Min <- -1;
trigger1Max <- 3000;
trigger2Min <- -1;
trigger2Max <- 3000;

agent.on("Trigger1Min", function(data) {
  //do something with data.. maybe write out to pins or something
  trigger1Min = (data.trigger1min);
  server.log("trigger1min set to " + data.trigger1min);
});
agent.on("Trigger1Max", function(data) {
  //do something with data.. maybe write out to pins or something
  trigger1Max = (data.trigger1max);
  server.log("trigger1max set to " + data.trigger1max);
});
agent.on("Trigger2Min", function(data) {
  //do something with data.. maybe write out to pins or something
  trigger2Min = (data.trigger2min);
  server.log("trigger1min set to " + data.trigger2min);
});
agent.on("Trigger2Max", function(data) {
  //do something with data.. maybe write out to pins or something
  trigger2Max = (data.trigger2max);
  server.log("trigger2max set to " + data.trigger2max);
});
// Screen class to manage the LCD
class Screen {
    port = null;
    lines = null;
    positions = null;

    constructor(_port) {
        port = _port;
        lines = ["Initializing...", ""];
        positions = [0, 0];
    }
    
    function set0(line) {
        lines[0] = line;
    }
    
    function set1(line) {
        lines[1] = line;
    }
    
    function clear_screen() {
        port.write(0xFE);
        port.write(0x01);
    }
    
    function cursor_at_line0() {
        port.write(0xFE);
        port.write(128);
    }
    
    function cursor_at_line1() {
        port.write(0xFE);
        port.write(192);
    }
    
    function write_string(string) {
        foreach(i, char in string) {
            port.write(char);
        }
    }
    
    function start() {
        update_screen();
    }
    
    function update_screen() {
        imp.wakeup(0.4, update_screen.bindenv(this));
        
        cursor_at_line0();
        display_message(0);
        
        cursor_at_line1();
        display_message(1);
    }
    
    function display_message(idx) {  
        local message = lines[idx];
        
        local start = positions[idx];
        local end   = positions[idx] + 16;
        
    
        if (end > message.len()) {
            end = message.len();
        }
    
        local string = message.slice(start, end);
        for (local i = string.len(); i < 16; i++) {
            string  = string + " ";
        }
    
        write_string(string);
    
        if (message.len() > 16) {
            positions[idx]++;
            if (positions[idx] > message.len() - 1) {
                positions[idx] = 0;
            }
        }
    }
}
//Define functions
function readChip189(){
        // Begin converting Binary data for chip 1
    local tc = 0;
    if ((temp32[1] & 1) ==1){
    	
        //Error bit is set
		
		local errorcode = (temp32[3] & 7);// 7 is B00000111
		local TCErrCount = 0;
		if (errorcode>0){
			
			//One or more of the three error bits is set
			//B00000001 open circuit
			//B00000010 short to ground
			//B00000100 short to VCC
			
			switch (errorcode){
            
            case 1:
			    
                server.log("TC open circuit");
			    break;
			
			case 2:
            
                server.log("TC short to ground");
			    break;
            
            case 3:
            
                server.log("TC open circuit and short to ground")
                break;
			
			case 4:
            
                server.log("TC short to VCC");
			    break;
			
			default:
            
                //Bad coding error if you get here
			    break;
			}
			
			TCErrCount+=1;
			//if there is a fault return this number, or another number of your choice
			 tc= 67108864; 
		}
	    else
        {
             server.log("error in SPI read");
        }
        
	} 
	else //No Error code raised
	{
		local highbyte =(temp32[0]<<6); //move 8 bits to the left 6 places
		
        //move to the right two places, lowing two bits that were not related
		local lowbyte = (temp32[1]>>2);		
		tc = highbyte | lowbyte; //now have right-justifed 14 bits but the 14th digit is the sign
         
		//Shifting the bits to make sure negative numbers are handled
        
        //get the sign indicator into position 31 of the signed 32-bit integer
		
        //Then, scale the number back down, the right-shift operator of squirrel/impOS
        //seems to handle the sign bit
        
        tc = ((tc<<18)>>18); 
        // Convert to Celcius
		celcius = (1.0* tc/4.0);
        // Convert to Farenheit
        farenheit = (((celcius*9)/5)+32);
	}
}
// Read Probe 1
function probe1() {
        //Get SPI data 
    hardware.pin8.write(0); //pull CS low to start the transmission of temp data  
		//0[31..24],1[23..16],2[15..8],3[7..0]
        temp32=hardware.spi189.readblob(4);//SPI read is totally completed here
    hardware.pin8.write(1); // pull CS high
    readChip189();
    server.log("Probe 1: " + farenheit + "F");
    tempOut.set(farenheit);
    tempOutStr.set(format("%.01f", farenheit));
    screen.set0("Probe 1: " + farenheit + "F"); // Write the first line
    if (farenheit >= trigger1Max.tofloat()) {
        agent.send("Probe1", farenheit);
    }
    else if (farenheit <= trigger1Min.tofloat()) {
        agent.send("Probe1", farenheit);
    }
}
// Read Probe 2
function probe2() {    
    //Get SPI data 
    hardware.pin2.write(0); 
        temp32=hardware.spi189.readblob(4);
    hardware.pin2.write(1);
    readChip189();
    server.log("Probe 2: " + farenheit + "F");
    tempOut2.set(farenheit);
    tempOutStr2.set(format("%.01f", farenheit));
    screen.set1("Probe 2: " + farenheit + "F"); // Write the first line
    if (farenheit >= trigger2Max.tofloat()) {
        agent.send("Probe2", farenheit);
    }
    else if (farenheit <= trigger2Min.tofloat()) {
        agent.send("Probe2", farenheit);
    }    
}
function loop() {
    server.log("Triggers: " + trigger1Min + ", " + trigger1Max +", " + trigger2Min + ", " + trigger2Max);
    probe1();
    probe2();
    imp.wakeup(30, loop);
}
// Configure with the server
imp.configure("jTherm-Pro (Twilio)", [], [tempOut, tempOutStr, tempOut2, tempOutStr2]);
        screen <- Screen(port0);
        screen.clear_screen();
        screen.start();
loop();
