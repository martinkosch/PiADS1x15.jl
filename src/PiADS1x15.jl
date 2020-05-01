module PiADS1x15

using PiGPIO

export ADS1x15_Address, ADS1x15_Pointer, ADS1x15_Config_OS, ADS1x15_Config_MUX,
ADS1x15_Config_PGA, ADS1x15_Config_MODE, ADS1x15_Config_DR, ADS1x15_Config_COMPMODE,
ADS1x15_Config_COMPPOL, ADS1x15_Config_COMPLAT, ADS1x15_Config_COMPQUE
export ADS1015, ADS1115
export set_and_read_ADS1x15, set_threshold_alert, enable_conv_rdy_alert, is_busy

# I2C Addresses
@enum ADS1x15_Address begin
  ADDRESS_GND = 0x48 # I2C address if ADDR pin is connected to GND
  ADDRESS_VDD = 0x49 # I2C address if ADDR pin is connected to VCC
  ADDRESS_SDA = 0x4a # I2C address if ADDR pin is connected to SDA
  ADDRESS_SCL = 0x4b # I2C address if ADDR pin is connected to SCL
end

# Pointer register
@enum ADS1x15_Pointer begin
  POINTER_CONVERT = 0x00 # Conversion register
  POINTER_CONFIG = 0x01 # Config register
  POINTER_LOWTHRESH = 0x02 # Low threshold register
  POINTER_HITHRESH = 0x03 # High threshold register
end

# Config register
@enum ADS1x15_Config_OS begin
  OS_STRTSINGLE = 0x8000 # Write: Start a single-conversion
  OS_BUSY = 0x0000 # Read: Device is currently performing a conversion
end

@enum ADS1x15_Config_MUX begin
  MUX_DIFF_0_1 = 0x0000 # AIN_P = AIN0 and AIN_N = AIN1 (differential, default)
  MUX_DIFF_0_3 = 0x1000 # AIN_P = AIN0 and AIN_N = AIN3 (differential)
  MUX_DIFF_1_3 = 0x2000 # AIN_P = AIN1 and AIN_N = AIN3 (differential)
  MUX_DIFF_2_3 = 0x3000 # AIN_P = AIN2 and AIN_N = AIN3 (differential)
  MUX_SINGLE_0 = 0x4000 # AIN_P = AIN0 and AIN_N = GND (single-ended)
  MUX_SINGLE_1 = 0x5000 # AIN_P = AIN1 and AIN_N = GND (single-ended)
  MUX_SINGLE_2 = 0x6000 # AIN_P = AIN2 and AIN_N = GND (single-ended)
  MUX_SINGLE_3 = 0x7000 # AIN_P = AIN3 and AIN_N = GND (single-ended)
end

@enum ADS1x15_Config_PGA begin
  PGA_6144V = 0x0000 # +-6.144V range
  PGA_4_096V = 0x0200 # +-4.096V range
  PGA_2_048V = 0x0400 # +-2.048V range (default)
  PGA_1_024V = 0x0600 # +-1.024V range
  PGA_0_512V = 0x0800 # +-0.512V range
  PGA_0_256V = 0x0A00 # +-0.256V range
end

@enum ADS1x15_Config_MODE begin
  MODE_CONTINOUS = 0x0000 # Continuous-conversion mode
  MODE_SINGLE = 0x0100 # Single-shot mode or power-down state (default)
end

@enum ADS1x15_Config_DR begin
  DR_128SPS = 0x0000 # 128 samples per second
  DR_250SPS = 0x0020 # 250 samples per second
  DR_490SPS = 0x0040 # 490 samples per second
  DR_920SPS = 0x0060 # 920 samples per second
  DR_1600SPS = 0x0080 # 1600 samples per second (default)
  DR_2400SPS = 0x00A0 # 2400 samples per second
  DR_3300SPS = 0x00C0 # 3300 samples per second
end

@enum ADS1x15_Config_COMPMODE begin
  COMPMODE_TRAD = 0x0000 # Traditional comparator (default)
  COMPMODE_WINDOW = 0x0010 # Window comparator
end

@enum ADS1x15_Config_COMPPOL begin
  COMPPOL_ACTIVELOW = 0x0000 # Active low ALERT/RDY pin (default)
  COMPPOL_ACTIVEHI = 0x0008 # Active high ALERT/RDY pin
end

@enum ADS1x15_Config_COMPLAT begin
  COMPLAT_NONLAT = 0x0000 # Non-latching comparator (default)
  COMPLAT_LATCH = 0x0004 # Latching comparator
end

@enum ADS1x15_Config_COMPQUE begin
  COMPQUE_1CONV = 0x0000 # Assert ALERT/RDY after one conversions
  COMPQUE_2CONV = 0x0001 # Assert ALERT/RDY after two conversions
  COMPQUE_4CONV = 0x0002 # Assert ALERT/RDY after four conversions
  COMPQUE_NONE = 0x0003 # Disable the comparator and put ALERT/RDY to high impedance (default)
end

abstract type ADS1x15 end

mutable struct ADS1015 <: ADS1x15
  handle          # PiGPIO handle
  i2c_address      # I2C address
  conversion_delay # Conversion delay (s)
  bit_shift        # Bit shift
end

mutable struct ADS1115 <: ADS1x15
  handle          # PiGPIO handle
  i2c_address      # I2C address
  conversion_delay # Conversion delay (s)
  bit_shift        # Bit shift
end

function ADS1015(pi::Pi, i2c_bus::Integer, i2c_address::ADS1x15_Address)
  handle = PiGPIO.i2c_open(pi, i2c_bus, i2c_address)
  return ADS1015(handle, i2c_address, 1//1000, 4)
end

function ADS1115(pi::Pi, i2c_bus::Integer, i2c_address::ADS1x15_Address)
  handle = PiGPIO.i2c_open(pi, i2c_bus, i2c_address)
  return ADS1115(handle, i2c_address, 9//1000, 0)
end

"""
    write_register(pi, ads, register, value)

Write a 16-bits `value` to the specified destination `register`.
"""
function write_register(pi::Pi, ads::ADS1x15, register::Number, value::Number)
  return PiGPIO.i2c_write_word_data(pi, ads.i2c_handle, UInt8(register), UInt16(value))
end

"""
  read_register(pi, ads, register)

Read 16-bits from the specified destination `register`.
"""
function read_register(pi::Pi, ads::ADS1x15, register::Number)
  return PiGPIO.i2c_read_word_data(pi, ads.i2c_handle, UInt8(register))
end

"""
  set_and_read_ADS1x15(pi, ads [, os; mux, pga, mode, dr, comp_mode, comp_pol, comp_lat, comp_que])

Get a single-ended ADC reading from the specified `channel` on an `ads` ic and return the ADC reading
"""
function set_and_read_ADS1x15(pi::Pi, ads::ADS1x15, os::ADS1x15_Config_OS=OS_STRTSINGLE,
  mux::ADS1x15_Config_MUX=MUX_DIFF_0_1,
  pga::ADS1x15_Config_PGA=PGA_2_048V,
  mode::ADS1x15_Config_MODE=MODE_SINGLE,
  dr::ADS1x15_Config_DR=DR_1600SPS,
  comp_mode::ADS1x15_Config_COMPMODE=COMPMODE_TRAD,
  comp_pol::ADS1x15_Config_COMPPOL=COMPPOL_ACTIVELOW,
  comp_lat::ADS1x15_Config_COMPLAT=COMPLAT_NONLAT,
  comp_que::ADS1x15_Config_COMPQUE=COMPQUE_NONE)

  config = os | mux | pga | mode | dr | comp_mode | comp_pol | comp_lat | comp_que
  write_register(pi, ads, ADS1x15_POINTER_CONFIG, config)

  sleep(ads.conversion_delay)

  result = read_register(pi, ads, ADS1x15_POINTER_CONVERT) >> ads.bit_shift
  if ads.bit_shift != 0 && mux <= 0x3000 && result > 0x07FF
    result |= 0xF000 # Move sign to 16th bit in case of negative differential values
  end
  return result
end

"""
  set_threshold_ADS1x15(pi, ads, thld_value[, write_low_thld])

Set the low or high (see boolean `write_low_thld`) comperator alert threshold to a specific digital value `thld_value`.
Use function [`enable_conv_rdy_alert`](@ref) in order to enable a alert pin changes on newly available conversion results.
"""
function set_threshold_alert(pi::Pi, ads::ADS1x15, thld_value::Number, write_low_thld::Bool=true)
  register = write_low_thld ? ADS1x15_POINTER_LOWTHRESH : ADS1x15_POINTER_HITHRESH
  return write_register(pi, ads, register, thld_value << ads.bit_shift)
end

"""
  enable_conv_rdy_alert(pi, ads)

Enable alert pin changes on newly available conversion results.
"""
function enable_conv_rdy_alert(pi::Pi, ads::ADS1x15)
  write_register(pi, ads, ADS1x15_POINTER_LOWTHRESH, 0x800)
  write_register(pi, ads, ADS1x15_POINTER_HITHRESH, 0x7ff)
end

"""
  is_busy(pi, ads)

Check if ADC is currenty performing a measurement.
"""
function is_busy(pi::Pi, ads::ADS1x15)
  os_mask = 0x8000
  return read_register(pi, ads, ADS1x15_POINTER_CONFIG) & os_mask == OS_BUSY
end

end #module
