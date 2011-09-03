#!/usr/bin/python

# Shoe Agent - Listens for Nike+ Sensors and submits the UIDs to stumble.to
# Casey Halverson <spaceneedle@gmail.com>
# Eric Butler <eric@codebutler.com>

# Designed to work with the Nike+iPod Serial to USB Adapter from:
# http://www.sparkfun.com/commerce/product_info.php?products_id=8245

# Based on code from:
# http://www.borismus.com/nike-hacking-with-python/

import time
import sys
import serial
import urllib
import hashlib
import hmac
import json
import logging

# Adjust these values as appropriate.
API_KEY    = 'YOUR_API_KEY'
API_SECRET = 'YOUR_API_SECRET'
DEVICE     = '/dev/tty.usbserial-A600e18v'

class ShoeStumbler(object):
  def __init__(self):
    self._sensorCache = {}
    
  def listen(self):
    with serial.Serial(DEVICE, 57600, timeout=10) as ser:
      init = 'FF 55 04 09 07 00 25 C7'
      ser.write(self._hexToByte(init))

      resp = self._byteToHex(self._readBytes(ser, 8))
      assert resp == 'FF 55 04 09 00 00 07 EC'

      init = 'FF 55 02 09 05 F0'
      ser.write(self._hexToByte(init))
      
      resp = self._byteToHex(self._readBytes(ser, 8))
      assert resp == 'FF 55 04 09 06 00 25 C8'

      logging.info("nike+ initialized. listening for data")

      while True:
        self._readExactly(ser, self._hexToByte('FF 55 1E 09 0D 0D 01'))

        message = self._readBytes(ser, 27)
        self._handleUid(self._byteToHex(message[0:4]))

  def _handleUid(self, uid):
    self._expireCache() 
    if not uid in self._sensorCache:
      self._submit(uid)
      self._sensorCache[uid] = time.time()

  def _expireCache(self):
    stale = 600
    for key in self._sensorCache.copy():
      sensorTime = self._sensorCache[key]
      if sensorTime < (time.time() - stale):
        del self._sensorCache[key]

  def _submit(self, uid):
    uid = uid.replace(' ', '-').lower()
    logging.debug('Submitting: %s' % uid)
    devices = [
      { 'identifier': uid, 'type': 'shoe' }
    ]

    params = {
      'api_key': API_KEY,
      'devices': json.dumps(devices)
    }

    msg = []
    for k, v in sorted(params.iteritems()):
      msg.append('%s=%s' % (k, urllib.quote_plus(v)))
    msg = '&'.join(msg)

    sig = hmac.new(API_SECRET, msg, hashlib.sha512)
    params['signature'] = sig.hexdigest()
    params = urllib.urlencode(params)

    f = urllib.urlopen('http://stumble.to/api/update', params)
    result = f.read()
    logging.debug('Stumble.to result is: %s' % result)
  
  def _readBytes(self, ser, number):
    return ''.join( ser.read() for i in range(number) );
    
  def _readExactly(self, ser, bytes):
    while True:
      good = True
      for b in bytes:
        got = ser.read()
        if got != b:
          good = False
          break
      if good:
        return
      
  def _byteToHex(self, byteStr):
    return ''.join( [ "%02X " % ord( x ) for x in byteStr ] ).strip()
    
  def _hexToByte(self, hexStr):
    hexStr = hexStr.replace(' ', '')
    return ''.join( ["%c" % chr( int ( hexStr[i:i+2],16 ) ) \
      for i in range(0, len( hexStr ), 2) ] )

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s %(levelname)s %(message)s')

stumbler = ShoeStumbler()
while True:
  try:  
    stumbler.listen()
  except Exception, ex:
    logging.error("Error occurred! %s" % ex)
    
