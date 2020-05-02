module PiADS1x15

using PiGPIO

export ADS1015, ADS1115
export set_and_read_ADS1x15, set_threshold_alert, enable_conv_rdy_alert, is_busy

# I2C Addresses
const addresses = Dict(
  :GND => 0x48, # I2C address if ADDR pin is connected to GND
  :VDD => 0x49, # I2C address if ADDR pin is connected to VCC
  :SDA => 0x4a, # I2C address if ADDR pin is connected to SDA
  :SCL => 0x4b # I2C address if ADDR pin is connected to SCL
)

# Pointer register
const pointers = Dict(
  :CONVERT => 0x00, # Convert register
  :CONFIG => 0x01, # Config register
  :LOWTHRESH => 0x02, # Low threshold register
  :HITHRESH => 0x03 # High threshold register
)

# Config register
const config_os = Dict(
  :MASK_OS => 0x8000,
  :STRTSINGLE => 0x8000, # Write: Start a single-conversion
  :BUSY => 0x0000, # Read: Device is currently performing a conversion
  :NOTBUSY => 0x8000 # Read: Device is in idle mode
)

const config_mux = Dict(
  :MASK_MUX => 0x7000,
  :DIFF_0_1 => 0x0000, # AIN_P = AIN0 and AIN_N = AIN1 (differential, default)
  :DIFF_0_3 => 0x1000, # AIN_P = AIN0 and AIN_N = AIN3 (differential)
  :DIFF_1_3 => 0x2000, # AIN_P = AIN1 and AIN_N = AIN3 (differential)
  :DIFF_2_3 => 0x3000, # AIN_P = AIN2 and AIN_N = AIN3 (differential)
  :SINGLE_0 => 0x4000, # AIN_P = AIN0 and AIN_N = GND (single-ended)
  :SINGLE_1 => 0x5000, # AIN_P = AIN1 and AIN_N = GND (single-ended)
  :SINGLE_2 => 0x6000, # AIN_P = AIN2 and AIN_N = GND (single-ended)
  :SINGLE_3 => 0x7000 # AIN_P = AIN3 and AIN_N = GND (single-ended)
)

const config_pga = Dict(
  :MASK_PGA => 0x0E00,
  :V6_144 => 0x0000, # +-6.144V range
  :V4_096 => 0x0200, # +-4.096V range
  :V2_048 => 0x0400, # +-2.048V range (default)
  :V1_024 => 0x0600, # +-1.024V range
  :V0_512 => 0x0800, # +-0.512V range
  :V0_256 => 0x0A00 # +-0.256V range
)

const config_mode = Dict(
  :MASK_MODE => 0x0100,
  :CONTINOUS => 0x0000, # Continuous-conversion mode
  :SINGLE => 0x0100 # Single-shot mode or power-down state (default)
)

const config_dr = Dict(
  :MASK_DR => 0x00E0,
  :SPS128 => 0x0000, # 128 samples per second
  :SPS250 => 0x0020, # 250 samples per second
  :SPS490 => 0x0040, # 490 samples per second
  :SPS920 => 0x0060, # 920 samples per second
  :SPS1600 => 0x0080, # 1600 samples per second (default)
  :SPS2400 => 0x00A0, # 2400 samples per second
  :SPS3300 => 0x00C0 # 3300 samples per second
)

const config_compmode = Dict(
  :MASK_COMPMODE => 0x0010,
  :TRADITIONAL => 0x0000, # Traditional comparator (default)
  :WINDOW => 0x0010 # Window comparator
)

const config_comppol = Dict(
  :MASK_COMPPOL => 0x0008,
  :ACTIVELOW => 0x0000, # Active low ALERT/RDY pin (default)
  :ACTIVEHI => 0x0008 # Active high ALERT/RDY pin
)

const config_complat = Dict(
  :MASK_COMPLAT => 0x0004,
  :NONLATCH => 0x0000, # Non-latching comparator (default)
  :LATCH => 0x0004 # Latching comparator
)

const config_compque = Dict(
  :MASK_COMPQUE => 0x0003,
  :CONV1 => 0x0000, # Assert ALERT/RDY after one conversions
  :CONV2 => 0x0001, # Assert ALERT/RDY after two conversions
  :CONV4 => 0x0002, # Assert ALERT/RDY after four conversions
  :NONE => 0x0003 # Disable the comparator and put ALERT/RDY to high impedance (default)
)

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

function ADS1015(pi::Pi, i2c_bus::Integer, i2c_address::Symbol=:GND)
  global addresses
  handle = PiGPIO.i2c_open(pi, i2c_bus, addresses[i2c_address])
  return ADS1015(handle, i2c_address, 1//1000, 4)
end

function ADS1115(pi::Pi, i2c_bus::Integer, i2c_address::Symbol=:GND)
  global addresses
  handle = PiGPIO.i2c_open(pi, i2c_bus, addresses[i2c_address])
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
function set_and_read_ADS1x15(pi::Pi, ads::ADS1x15, os::Symbol=:STARTSINGLE,
  mux::Symbol=:DIFF_0_1,
  pga::Symbol=:V2_048,
  mode::Symbol=:SINGLE,
  dr::Symbol=:SPS1600,
  compmode::Symbol=:TRAD,
  comppol::Symbol=:ACTIVELOW,
  complat::Symbol=:NONLAT,
  compque::Symbol=:NONE)

  global pointers
  global config_os
  global config_mux
  global config_pga
  global config_mode
  global config_dr
  global config_compmode
  global config_comppol
  global config_complat
  global config_compque

  config = config_os[os] | config_mux[mux] | config_pga[pga] | config_mode[mode] | config_dr[dr] |
  config_compmode[compmode] | config_comppol[comppol] | config_complat[complat] | config_compque[compque]

  write_register(pi, ads, pointers[:CONFIG], config)
  sleep(ads.conversion_delay)

  result = read_register(pi, ads, pointers[:CONVERT]) >> ads.bit_shift
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
  global pointers
  register = write_low_thld ? pointers[:LOWTHRESH] : pointers[:HITHRESH]
  return write_register(pi, ads, register, thld_value << ads.bit_shift)
end

"""
  enable_conv_rdy_alert(pi, ads)

Enable alert pin changes on newly available conversion results.
"""
function enable_conv_rdy_alert(pi::Pi, ads::ADS1x15)
  global pointers
  write_register(pi, ads, pointers[:LOWTHRESH], 0x800)
  write_register(pi, ads, pointers[:HITHRESH], 0x7ff)
end

"""
  is_busy(pi, ads)

Check if ADC is currenty performing a measurement.
"""
function is_busy(pi::Pi, ads::ADS1x15)
  global pointers
  global config_os
  return read_register(pi, ads, pointers[:CONFIG]) & config_os[:MASK_OS] == config_os[:BUSY]
end

end #module
