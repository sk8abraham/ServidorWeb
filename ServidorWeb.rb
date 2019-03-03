#!/usr/bin/ruby
require 'socket'
require 'optparse'

options = {puerto:8080, directorio:".",bitacoras:nil,waf:nil,audit:"audit.log"}

optparse = OptionParser.new do |opt|
  opt.on('-p', '--puerto PUERTO', Integer, 'Numero de puerto') do |p| options[:puerto] = p
  end
  opt.on('-d', '--directorio DIRECTORIO', 'Directorio para montar el servidor') do |d| options[:directorio] = d
  end
  opt.on('-b', '--bitacoras DIRECTORIO', 'Directorio donde se encuentran las bitacoras') do |b| options[:bitacoras] = b
  end
  opt.on('-w', '--waf ARCHIVO_REGLAS', 'Habilitar Web Application Firewall') do |w| options[:waf] = w
  end
  opt.on('-a', '--audit ARCHIVO_AUDITORIAS', 'Archivo de bitacora del WAF') do |a| options[:audit] = a
  end
end

optparse.parse!

ruta = Dir.pwd+"/"
ruta_bitacoras = ""
ruta_reglas = ""

#Validacion de puerto
if options[:puerto] < 1 or options[:puerto] > 65535
  print("Puerto esta fuera del rango [1..65535]: #{options[:puerto].to_s}\n")
  exit
end


#Verificando que el archivo de reglas existe y obteniendo su ruta absoluta
if options[:waf] != nil
  if options[:waf].match(/^\/.*/)
    ruta_reglas = options[:waf]
  else
    ruta_reglas = ruta + options[:waf]
  end
  if !File.exist?(ruta_reglas)
    print "El archivo de reglas: " + ruta_reglas + " no existe\n"
    exit
   end
end


#Verificando que el directorio de bitacoras existe y obteniendo su ruta absoluta
if options[:bitacoras] != nil
  if options[:bitacoras].match(/^\/.*/)
    ruta_bitacoras = options[:bitacoras]
  else
    ruta_bitacoras = ruta + options[:bitacoras]
  end
  if !Dir.exist?(ruta_bitacoras)
    print "La ruta no es valida\n"
    exit
  end
end


#Cambiando de directorio al que se vaya a montar el servidor
if Dir.exist?(options[:directorio])
  Dir.chdir options[:directorio]
  print "Directorio donde se monto: #{Dir.pwd}\n"
  print "Archivos en el servidor: #{Dir["*"]}\n"
else 
  print "Ruta no valida"
  exit
end




DIRECTORY_ROOT = '.'


# Creacion de funciones con cada metodo
def metodo_GET(resource)
  full_path = Dir.pwd+resource
  puts "Este es el path GET: " + resource
  response = ''
  #path,argumentos = path.match(/(.*)\?(.*)/).captures
  puts resource
  #puts argumentos
  ext=File.extname(resource)
  if ext == ".cgi"
    puts "------- Archivo cgi ----------"
    puts "Extension es: "+ ext
  #elsif argumentos
  #  puts "------- Archivo cgi con argumentos----------"
  #  puts argumentos
  elsif ext != ".cgi"
    puts "Extension es: "+ ext
    file = File.read(full_path)
    response = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: text/html\r\n" +
                "Content-Length: #{file.size}\r\n" +
                #"Connection: close\r\n"+
                "\r\n"+
                file
  else
    message = "File not found\n"
    response = "HTTP/1.1 404 Not Found\r\n" +
                 "Content-Type: text/html\r\n" +
                 "Content-Length: #{message.size}\r\n" +
                 "Connection: close\r\n" +
                 "\r\n" +
                 message
  end
  return response
end
def metodo_POST(resource)
  puts "Este es el path POST: " + resource
end

def metodo_HEAD(resource)
  puts "Este es el path HEAD: " + resource
end


def requested_file(client, request)
  puts "Request: "+request
  method, resource, version = request.lines[0].split
  puts "Metodo: "+ method
  puts "Path: "+ resource
  puts "Version: "+ version
  response = ""
  if resource == "/"
    resource = File.join(resource, 'index.html') if File.directory?(resource)
    # No aseguramos que el archivo existe y no es un directorio
    # antes de intentar abrirla.
    resource = Dir.pwd+resource
    if File.exist?(resource) && !File.directory?(resource)
      puts "-------REDIRECCION a Index.html------------"
      file = File.read(resource)
      response = "HTTP/1.1 302 Found\r\n" +
                  "Location: /index.html\n" +
                  "Content-Type: text/html\r\n" +
                  "Content-Length: #{file.size}\r\n" +
                  #"Connection: close\r\n"+
                  "\r\n"+
                  file
      return response
    else
        message = "File not found\n"
        # Responde con un codigo 404 error que indica que no exixte el archivo
        response = "HTTP/1.1 404 Not Found\r\n" +
                     "Content-Type: text/html\r\n" +
                     "Content-Length: #{message.size}\r\n" +
                     "Connection: close\r\n" +
                     "\r\n"
                     message
    end
  end


    #------------
=begin
    clean = []

    # Split the path into components
    parts = path.split("/")

    parts.each do |part|
      # Omitir cualquier directorio vacío o actual (".") componentes de ruta de acceso
      next if part.empty? || part == '.'
      # Si el componente path sube un nivel de directorio (".."),
      # Quite el último componente limpio.
      # De lo contrario, añada el componente a la matriz de componentes limpios
      part == '..' ? clean.pop : clean << part
    end

    # regresamos el DIRECTORY_ROOT limpio
    File.join(DIRECTORY_ROOT, *clean)
  end
=end
  if method == "GET"
    response = metodo_GET(resource)
  elsif method == "POST"
    response = metodo_POST(resource)
  elsif method == "HEAD"
    response = metodo_HEAD(resource)
  else
    message = "Method not allowed"
    response = "HTTP/1.1 500 Method not allowed\r\n" +
                 "Content-Type: text/html\r\n" +
                 "Content-Length: #{message.size}\r\n" +
                 "Connection: close\r\n" +
                 "\r\n"
                 message
  end
  return response
end

def parse_headers(request)
  headers{}
  request.lines[1..-1].each do |line|
    return headers if line == "\r\n"
    header, value = line.split
    header        = normalize(header)
    headers[header] = value
  end
  def normalize(header)
    header.gsub(":","").downcase.to_sym
  end
end

#---------------- Creacion del servidor Web --------------------#
hostname = 'localhost'
port = 8080

server = TCPServer.new(hostname, port)
puts "Servidor Corriendo en "+hostname+":"+port.to_s
loop do
  # Creamos un hilo por cada cliente que se conecte al Servidor
  Thread.start(server.accept) do |client|
    sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
    #puts sock_domain
    puts remote_port
    puts remote_hostname
    puts remote_ip
    request = client.readpartial(2048)
    response = requested_file(client, request)
    client.puts response
    client.close
  end
end



=begin
puts "Servidor Corriendo en "+hostname+":"+port.to_s
while client = server.accept
  sock_domain, remote_port, remote_hostname, remote_ip = server.peeraddr
  puts sock_domain
  puts remote_port
  puts remote_hostname
  puts remote_ip
  request = client.readpartial(2048)
  response = requested_file(client, request)
  client.puts response
  client.close
end
=end
