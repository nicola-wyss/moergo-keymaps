require 'rake/clean'
require 'json'
require 'erb'


#-----------------------------------------------------------------------------
# Source and output directories
#-----------------------------------------------------------------------------

KB        = ENV.fetch('KB', 'go60')
COMBOSET  = ENV.fetch('COMBO', 'A')
BUILD_DIR = "build/#{KB}"
PDF_DIR   = "#{BUILD_DIR}/pdf"
KB_DIR    = "keyboards/#{KB}"
ENV['BUILD_DIR'] = BUILD_DIR
ENV['KB_DIR']    = KB_DIR

directory BUILD_DIR
directory PDF_DIR

task :default => [:keymap, :dot, :pdf, :device]

#-----------------------------------------------------------------------------
# Keymap.dtsi
#
# Usage:   pasted into MoErgo Layout Editor (Custom Defined Behavior)
# Inputs:  The zmk and json export from the Layout Editor in keyboards/#{KB}/editorExports
# Outputs: build/#{KB}/keymap.dtsi
#-----------------------------------------------------------------------------

keymap_zmk_file = Dir.glob("#{KB_DIR}/editorExports/*.{zmk,keymap}").first or
  abort "No .zmk or .keymap export found in #{KB_DIR}/editorExports/"
keymap_zmk = File.readlines(keymap_zmk_file)
POS_BY_KEY = keymap_zmk.grep(/^#define POS_[LR]H_\w+ \d+/).map do |line|
  (_define, name, value) = line.split
  key = name[/_(.+)/, 1]
  pos = Integer(value)
  [key, pos]
end.to_h
KEY_BY_POS = POS_BY_KEY.invert

FINGER_KEYS = keymap_zmk.grep(/^\s*#define \w+_(?:PINKY|RINGY|MIDDY|INDEX)_KEY\b/).map do |line|
  parts = line.split
  [parts[1], parts[2]]
end.to_h

keymap_erb = "shared/keymap.dtsi.erb"
keymap_out = "#{BUILD_DIR}/keymap.dtsi"
keymap_min = "#{keymap_out}.min"
keymap_tmp = "#{BUILD_DIR}/keymap.dtsi.erb.tmp"

keymap_deps = FileList[
  keymap_erb,
  'shared/keymap/behaviors.dtsi.erb',
  "shared/combos/comboset#{COMBOSET}.dtsi.erb",
  "#{KB_DIR}/combos/comboset#{COMBOSET}.dtsi.erb",
  *Dir.glob("#{KB_DIR}/editorExports/*.{json,zmk,keymap}"),
  'shared/chars/*.yaml',
  __FILE__
]
keymap_deps << "#{KB_DIR}/homeRowKeys.dtsi.erb" if FINGER_KEYS.empty?
keymap_deps << "#{KB_DIR}/handKeys.dtsi.erb"

file keymap_out => [BUILD_DIR, *keymap_deps] do |t|
  input = File.read(keymap_erb)
    .gsub(/\n(?= *<%(?!=))/, '')
  template = ERB.new(input, trim_mode: '<>')
  template.filename = keymap_tmp
  File.write(keymap_tmp, input)
  output = template.result()
    .gsub(/ +$/, '')
    .gsub(/\n+(?= +#(?!define))/, "\n")
  File.write(t.name, output)
  # keymap_tmp holds the preprocessed ERB source; ERB uses it for error backtraces.
  # Keep it with DEBUG=1 (e.g. `rake DEBUG=1`) to inspect line numbers on failures.
  File.delete(keymap_tmp) unless ENV['DEBUG']
end

file keymap_min => keymap_out do |t|
  minified = File.read(keymap_out)
    .gsub(%r{^\s*//(?! ==== ).*}, '')
    .gsub(%r{(?<=[^\*])//.*}, '')
    .gsub(/^\s+/, '')
    .squeeze("\n")
    .squeeze(' ')
  File.write(t.name, minified)
end

task :keymap => keymap_out

#-----------------------------------------------------------------------------
# Device - Custom device tree overlay
#
# Usage:   pasted into MoErgo Layout Editor (Custom Device-tree)
# Inputs:  keyboards/#{KB}/device.dtsi.erb
# Outputs: build/#{KB}/device.dtsi
#-----------------------------------------------------------------------------

device_erb = "shared/device.dtsi.erb"
device_out = "#{BUILD_DIR}/device.dtsi"
device_tmp = "#{BUILD_DIR}/device.dtsi.erb.tmp"

file device_out => [BUILD_DIR, device_erb, "#{KB_DIR}/device.dtsi.erb", __FILE__] do |t|
  input = File.read(device_erb)
    .gsub(/\n(?= *<%(?!=))/, '')
  template = ERB.new(input, trim_mode: '<>')
  template.filename = device_tmp
  File.write(device_tmp, input)
  output = template.result()
    .gsub(/ +$/, '')
    .gsub(/\n+(?= +#(?!define))/, "\n")
  File.write(t.name, output)
  # device_tmp holds the preprocessed ERB source; ERB uses it for error backtraces.
  # Keep it with DEBUG=1 (e.g. `rake DEBUG=1 device`) to inspect line numbers on failures.
  File.delete(device_tmp) unless ENV['DEBUG']
end

task :device => device_out

#-----------------------------------------------------------------------------
# Dot - Devinitions and timing graph (and sheet)
#
# Usage:   svg to inspect timings
# Inputs:  rake KB=* keymap output
# Outputs: build/#{KB}/define.svg, define.json, define.dot
#-----------------------------------------------------------------------------

define_dot  = "#{BUILD_DIR}/define.dot"
define_svg  = "#{BUILD_DIR}/define.svg"
define_json = "#{BUILD_DIR}/define.json"
keymap_mins      = [keymap_min]

task :dot => [define_svg, define_json]

file define_svg => define_dot do |t|
  sh "dot -Tsvg #{t.prerequisites[0]} > #{t.name}"
  # define_dot is intermediate; the SVG is the real output.
  # Keep it with DEBUG=1 (e.g. `rake DEBUG=1`) to inspect the raw DOT source.
  File.delete(define_dot) unless ENV['DEBUG']
end

file define_dot => [BUILD_DIR, 'shared/define.dot.erb', *keymap_mins] do |t|
  sh "erb shared/define.dot.erb > #{t.name}"
end

file define_json => [BUILD_DIR, *keymap_mins] do |t|
  defaults =
    `grep -h -A1 '#ifndef' #{keymap_mins.join(' ')} | grep '#define'`
    .gsub(/#define (\w+)/, '\1 =')
    .lines.inject({}) do |hash, line|
      setting = line[/\w+/]
      value =
        begin
          eval(line)
        rescue Exception
          warn "#{t.name}: skipped #{line.inspect}"
        end
      hash[setting] = value if value
      hash
    end
  File.write(t.name, JSON.pretty_generate({defaults: defaults}))
end

#-----------------------------------------------------------------------------
# pdf - printable layer map diagrams
#
# Usage:   Converts layout PNGs to a merged and individual PDFs
# Inputs:  keyboards/#{KB}/layoutPNGs/*.png
# Outputs: build/#{KB}/pdf/*.pdf
#-----------------------------------------------------------------------------

layers_pdf = "#{PDF_DIR}/all-layer-diagrams.pdf"
task :pdf => layers_pdf

layer_pngs = Dir["#{KB_DIR}/layerPNGs/*.png"].sort

layer_pdfs = layer_pngs.map do |png|
  pdf = "#{PDF_DIR}/#{png.pathmap('%n')}.pdf"
  file pdf => [PDF_DIR, png] do |t|
    sh 'gm', 'convert', png, t.name
  end
  CLEAN.include pdf
  pdf
end

file layers_pdf => [PDF_DIR, *layer_pdfs] do |t|
  sh 'pdfunite', *layer_pdfs, t.name
end

CLOBBER.include BUILD_DIR
