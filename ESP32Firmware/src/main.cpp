/**
 * ESP32 Collar Bridge Firmware
 *
 * Acts as a BLE GATT server that receives commands from the iOS app
 * and translates them to 433MHz RF signals for Mini Educator e-collars.
 *
 * HARDWARE WIRING:
 *   433MHz Transmitter (MX-FS-03V or similar):
 *     DATA -> GPIO 4
 *     VCC  -> 3.3V (or 5V for better range)
 *     GND  -> GND
 *   Optional: Solder a 17cm wire to the antenna pad for better range.
 *
 *   Status LED: GPIO 2 (built-in on most ESP32 dev boards)
 *
 * RF PROTOCOL NOTE:
 *   The Mini Educator's RF protocol is proprietary. This firmware provides
 *   a modular RF layer with a reference implementation based on similar
 *   433MHz OOK (On-Off Keying) collar protocols (e.g. PET998D).
 *
 *   To use with YOUR Mini Educator:
 *   1. Get an RTL-SDR dongle (~$10) and install Universal Radio Hacker
 *   2. Record your remote sending each command (stim, vibrate, tone)
 *   3. Decode the OOK bit patterns and timing
 *   4. Update the RFProtocol config below with your captured values
 *   5. The remote ID bits are what pairs the remote to the collar
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ============================================================
// Pin Configuration
// ============================================================
#define RF_TX_PIN       4   // 433MHz transmitter DATA pin
#define STATUS_LED_PIN  2   // Built-in LED

// ============================================================
// BLE UUIDs (must match iOS app BLEProtocol.swift)
// ============================================================
#define SERVICE_UUID           "0000CC01-0000-1000-8000-00805F9B34FB"
#define COMMAND_CHAR_UUID      "0000CC02-0000-1000-8000-00805F9B34FB"
#define STATUS_CHAR_UUID       "0000CC03-0000-1000-8000-00805F9B34FB"

// ============================================================
// RF Protocol Configuration
// ============================================================
// These values are for a PET998D-style protocol as a reference.
// You MUST update these after capturing your Mini Educator's signals.
struct RFProtocol {
    // Pulse timing (microseconds)
    uint16_t shortPulse = 250;   // Short pulse width
    uint16_t longPulse  = 750;   // Long pulse width
    uint16_t syncHigh   = 250;   // Sync pulse high
    uint16_t syncLow    = 2500;  // Sync pulse low (gap)

    // Remote ID - unique per remote, captured via RTL-SDR
    // This is what pairs the remote to the collar.
    // Format: array of bits (0/1), typically 16-40 bits.
    uint8_t remoteID[16] = {0,1,0,1, 1,0,1,0, 0,0,1,1, 1,1,0,0};
    uint8_t remoteIDLength = 16;

    // Command codes (collar-specific, captured via RTL-SDR)
    uint8_t stimCode   = 0x01;
    uint8_t vibrateCode = 0x02;
    uint8_t toneCode    = 0x03;

    // Number of times to repeat the RF transmission for reliability
    uint8_t repeatCount = 4;
};

RFProtocol rfConfig;

// ============================================================
// BLE State
// ============================================================
BLEServer* pServer = nullptr;
BLECharacteristic* pCommandChar = nullptr;
BLECharacteristic* pStatusChar = nullptr;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// ============================================================
// Command packet structure (matches iOS app CollarCommand)
// ============================================================
struct CommandPacket {
    uint8_t collarID;
    uint8_t commandType;
    uint8_t level;
    uint8_t duration;
    uint16_t crc;
};

// ============================================================
// CRC-16/CCITT (must match iOS app implementation)
// ============================================================
uint16_t crc16(const uint8_t* data, size_t length) {
    uint16_t crc = 0xFFFF;
    for (size_t i = 0; i < length; i++) {
        crc ^= (uint16_t)data[i] << 8;
        for (int j = 0; j < 8; j++) {
            if (crc & 0x8000)
                crc = (crc << 1) ^ 0x1021;
            else
                crc = crc << 1;
        }
    }
    return crc;
}

// ============================================================
// RF Transmission
// ============================================================

/// Send a single bit via OOK modulation
void sendBit(bool bit) {
    if (bit) {
        // Bit 1: long high, short low
        digitalWrite(RF_TX_PIN, HIGH);
        delayMicroseconds(rfConfig.longPulse);
        digitalWrite(RF_TX_PIN, LOW);
        delayMicroseconds(rfConfig.shortPulse);
    } else {
        // Bit 0: short high, long low
        digitalWrite(RF_TX_PIN, HIGH);
        delayMicroseconds(rfConfig.shortPulse);
        digitalWrite(RF_TX_PIN, LOW);
        delayMicroseconds(rfConfig.longPulse);
    }
}

/// Send a sync/preamble pulse
void sendSync() {
    digitalWrite(RF_TX_PIN, HIGH);
    delayMicroseconds(rfConfig.syncHigh);
    digitalWrite(RF_TX_PIN, LOW);
    delayMicroseconds(rfConfig.syncLow);
}

/// Send a byte as 8 bits MSB first
void sendByte(uint8_t value) {
    for (int i = 7; i >= 0; i--) {
        sendBit((value >> i) & 1);
    }
}

/// Send a complete RF command to a collar.
/// This is the main function you'd customize for your specific collar protocol.
void sendRFCommand(uint8_t collarID, uint8_t commandType, uint8_t level) {
    Serial.printf("RF TX: collar=%d cmd=%d level=%d\n", collarID, commandType, level);

    // Disable interrupts for precise timing
    noInterrupts();

    for (int repeat = 0; repeat < rfConfig.repeatCount; repeat++) {
        // 1. Send preamble/sync
        sendSync();

        // 2. Send remote ID bits
        for (int i = 0; i < rfConfig.remoteIDLength; i++) {
            sendBit(rfConfig.remoteID[i]);
        }

        // 3. Send collar channel (4 bits)
        for (int i = 3; i >= 0; i--) {
            sendBit((collarID >> i) & 1);
        }

        // 4. Send command type byte
        sendByte(commandType);

        // 5. Send level byte
        sendByte(level);

        // 6. End-of-message gap
        digitalWrite(RF_TX_PIN, LOW);
        delayMicroseconds(rfConfig.syncLow * 2);
    }

    interrupts();
}

// ============================================================
// BLE Callbacks
// ============================================================

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
        deviceConnected = true;
        Serial.println("BLE client connected");
        digitalWrite(STATUS_LED_PIN, HIGH);
    }

    void onDisconnect(BLEServer* pServer) override {
        deviceConnected = false;
        Serial.println("BLE client disconnected");
        digitalWrite(STATUS_LED_PIN, LOW);
    }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) override {
        std::string value = pCharacteristic->getValue();

        if (value.length() != 6) {
            Serial.printf("Invalid packet length: %d\n", value.length());
            return;
        }

        // Parse command packet
        CommandPacket cmd;
        cmd.collarID    = (uint8_t)value[0];
        cmd.commandType = (uint8_t)value[1];
        cmd.level       = (uint8_t)value[2];
        cmd.duration    = (uint8_t)value[3];
        cmd.crc         = ((uint16_t)(uint8_t)value[4] << 8) | (uint8_t)value[5];

        // Verify CRC
        uint16_t expectedCRC = crc16((const uint8_t*)value.data(), 4);
        if (cmd.crc != expectedCRC) {
            Serial.printf("CRC mismatch: got 0x%04X expected 0x%04X\n", cmd.crc, expectedCRC);
            sendStatus("ERR:CRC");
            return;
        }

        // Validate
        if (cmd.collarID > 15) {
            Serial.println("Invalid collar ID");
            sendStatus("ERR:ID");
            return;
        }

        Serial.printf("CMD: collar=%d type=%d level=%d duration=%d\n",
                       cmd.collarID, cmd.commandType, cmd.level, cmd.duration);

        // Map command type to RF code
        uint8_t rfCode;
        switch (cmd.commandType) {
            case 0x01: rfCode = rfConfig.stimCode; break;
            case 0x02: rfCode = rfConfig.vibrateCode; break;
            case 0x03: rfCode = rfConfig.toneCode; break;
            default:
                Serial.println("Unknown command type");
                sendStatus("ERR:CMD");
                return;
        }

        // Send RF command
        sendRFCommand(cmd.collarID, rfCode, cmd.level);

        // Send success status back to phone
        char status[32];
        snprintf(status, sizeof(status), "OK:%d:%d:%d", cmd.collarID, cmd.commandType, cmd.level);
        sendStatus(status);

        // Blink LED to indicate transmission
        digitalWrite(STATUS_LED_PIN, LOW);
        delay(50);
        digitalWrite(STATUS_LED_PIN, HIGH);
    }

    void sendStatus(const char* msg) {
        if (pStatusChar != nullptr) {
            pStatusChar->setValue(msg);
            pStatusChar->notify();
        }
    }
};

// ============================================================
// Setup & Loop
// ============================================================

void setup() {
    Serial.begin(115200);
    Serial.println("\n=== Collar Bridge v1.0 ===");
    Serial.println("Initializing...");

    // Pin setup
    pinMode(RF_TX_PIN, OUTPUT);
    pinMode(STATUS_LED_PIN, OUTPUT);
    digitalWrite(RF_TX_PIN, LOW);
    digitalWrite(STATUS_LED_PIN, LOW);

    // Initialize BLE
    BLEDevice::init("CollarBridge");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    // Create collar control service
    BLEService* pService = pServer->createService(SERVICE_UUID);

    // Command characteristic (write without response)
    pCommandChar = pService->createCharacteristic(
        COMMAND_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE_NR
    );
    pCommandChar->setCallbacks(new CommandCallbacks());

    // Status characteristic (notify)
    pStatusChar = pService->createCharacteristic(
        STATUS_CHAR_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pStatusChar->addDescriptor(new BLE2902());

    // Start service and advertising
    pService->start();
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    BLEDevice::startAdvertising();

    Serial.println("BLE advertising started. Waiting for connection...");
    Serial.println("Device name: CollarBridge");
    Serial.printf("RF TX Pin: GPIO %d\n", RF_TX_PIN);
}

void loop() {
    // Handle reconnection
    if (!deviceConnected && oldDeviceConnected) {
        delay(500);
        BLEDevice::startAdvertising();
        Serial.println("Restarted advertising");
        oldDeviceConnected = deviceConnected;
    }

    if (deviceConnected && !oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
    }

    // Heartbeat blink when disconnected
    if (!deviceConnected) {
        digitalWrite(STATUS_LED_PIN, HIGH);
        delay(100);
        digitalWrite(STATUS_LED_PIN, LOW);
        delay(2900);
    } else {
        delay(100);
    }
}
