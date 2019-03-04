#!/usr/bin/ruby
require 'socket'
require 'optparse'
require "open3"
require 'date'
require_relative 'waf'

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
ruta_bitacoras = nil
ruta_reglas = nil

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
  verifica_reglas(ruta_reglas)
end


#Verificando que el directorio de bitacoras existe y obteniendo su ruta absoluta
if options[:bitacoras] != nil
  if options[:bitacoras].match(/^\/.*/)
    ruta_bitacoras = options[:bitacoras]+"/"
  else
    ruta_bitacoras = ruta + options[:bitacoras]+"/"
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

DIRECTORY_ROOT = Dir.pwd

def run_cgi(nom_file, request, client, argumentos=nil)
  std_out = ''
  inter = ''
  full_path = Dir.pwd + nom_file
  headers = parse_headers(request)
  #puts headers
  puts argumentos
  sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
  method, resource, version = request.lines[0].split
  if argumentos != nil
    ENV['QUERY_STRING'] = argumentos
    args = argumentos.split("&")
    if args
      for arg in args
        name, value = arg.split(/=/)
        ENV[name] = value
        puts ENV[name]
      end
    end
  else
    ENV['QUERY_STRING'] = argumentos
  end
  puts ENV['QUERY_STRING']
  ENV['SERVER_SOFTWARE'] = "Python BecarioWeb2"
  puts ENV['SERVER_SOFTWARE']
  ENV['DOCUMENT_ROOT'] = DIRECTORY_ROOT
  puts ENV['DOCUMENT_ROOT']
  ENV['SERVER_PROTOCOL'] = version
  puts ENV['SERVER_PROTOCOL']
  ENV['SERVER_PORT'] = PORT.to_s
  puts ENV['SERVER_PORT']
  ENV['REQUEST_METHOD'] = method
  puts ENV['REQUEST_METHOD']
  ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'
  puts ENV['GATEWAY_INTERFACE']
  ENV['REQUEST_URI'] = resource
  puts ENV['REQUEST_URI']
  ENV['REMOTE_ADDR'] = remote_ip
  puts ENV['REMOTE_ADDR']
  ENV['REMOTE_PORT'] = remote_port.to_s
  puts ENV['REMOTE_PORT']
  ENV['HTTP_USER_AGENT'] = headers["User-Agent"]
  puts ENV['HTTP_USER_AGENT']
  ENV['HTTP_COOKIE'] = headers["cookie"]
  puts ENV['HTTP_COOKIE']
  ENV['HTTP_REFERER'] = headers["Referer"]
  puts ENV['HTTP_REFERER']
  # Leemos el "shebang" del archivo CGI para saber que interprete usar
  shebang = File.open(full_path) {|f| f.readline}
  puts "shebang: "+shebang
  if shebang == "#!/usr/bin/python\n" or shebang == "#!/usr/bin/env python\n"
    inter = "python"
    puts inter
  elsif shebang == "#!/usr/bin/perl\n" or shebang == "#!/usr/local/bin/perl\n"
    inter = "perl"
    puts inter
  elsif shebang == "#!/usr/bin/php\n"
    inter = "php"
    puts inter
  end
  # Creamos el comando para que se mandara a llamar dentro de sistema
  cmd = "#{inter} #{full_path}"
  puts cmd
  puts "############################   CGI"
  Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
    #std_out = stdout.read
    #print "############################ pase"
    #puts stderr.read
    #stdin.close
    #puts std_out
    stdin.puts
    stdin.close
    std_out = stdout.read
    std_err = stderr.read
    status = wait_thr.value
  end
  return std_out
end

# Creacion de funciones con cada metodo
def metodo_GET(resource,request,client)
  puts "Este es el path GET: " + resource
  response = ''
  nom_file,argumentos=resource.split("?")
  ext = File.extname(nom_file)
  if ext == ".cgi"
    puts "------- Archivo cgi ----------"
    if argumentos == nil
      file = run_cgi(nom_file, request, client)
      response = "HTTP/1.1 200 OK\r\n" + file
    else
      file = run_cgi(nom_file, request, client, argumentos)
      response = "HTTP/1.1 200 OK\r\n" + file
    end
  elsif ext != ".cgi"
    full_path = Dir.pwd+nom_file
    puts full_path
    puts "------- Archivo no es cgi ----------"
    puts "Extension es: "+ ext
    file = File.read(full_path)
    response = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: text/html\r\n" +
                "Content-Length: #{file.size}\r\n" +
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

#----------- Metodo POST -----------#
def metodo_POST(resource, request, client)
  puts "Este es el path POST: " + resource
  response = ''
  argumentos = ''
  request.lines[-2..-1].each do |line|
    argumentos = line
  end
  #nom_file,argumentos=resource.split("?")
  ext = File.extname(resource)
  if ext == ".cgi"
    puts "------- Archivo cgi ----------"
    file = run_cgi(resource, request, client, argumentos)
    puts "################################################"
    response = "HTTP/1.1 200 OK\r\n" + file
  elsif ext != ".cgi"
    full_path = Dir.pwd+nom_file
    puts full_path
    puts "------- Archivo no es cgi ----------"
    puts "Extension es: "+ ext
    file = File.read(full_path)
    response = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: text/html\r\n" +
                "Content-Length: #{file.size}\r\n" +
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
  puts "Respuesta: ----------------------"
  puts response
  return response
end

def metodo_HEAD(resource)
  puts "Este es el path HEAD: " + resource
end

def logs(ip_cliente, fecha, mensaje, status, len_request, pid, tid, archivo, ruta_bitacoras, tipo)
    cadena1 = ip_cliente.to_s+" -- ["+fecha+"] "+mensaje+" "+status+" "+ len_request+"\n"
    cadena2 = "["+fecha+"] [core:error] [pid "+pid+":tid "+tid+"] [client "+ ip_cliente.to_s+"] File does not exist: "+archivo+"\n"
  if ruta_bitacoras != nil and tipo == "a"
    arch = ruta_bitacoras+"access.log"
    File.write(arch, cadena1 ,mode:'a')
  elsif ruta_bitacoras == nil and tipo == "a"
    print(cadena1)
  end

  if ruta_bitacoras != nil and tipo == "e"
    arch = ruta_bitacoras+"error.log"
    File.write(arch, cadena2 ,mode:'a')
  elsif ruta_bitacoras == nil and tipo == "e"
    print(cadena2)
    
  end 
end



def requested_file(client, request, opt_waf, puerto_cliente, ip_cliente, opt_audit, ruta_bitacoras)
  ###
  fecha = Time.now.strftime("%d/%m/%Y %H:%M:%S %Z")	
  codigos = {"403" => "Forbidden","404" => "Not Found", "500" => "Internal Server Error"}
  codigo_waf=""
  if opt_waf != nil
    codigo_waf = waf(opt_waf, request, puerto_cliente, ip_cliente, PORT, HOSTNAME,  opt_audit)
  end
  puts "Request: "+request
  method, resource, version = request.lines[0].split
  puts "Metodo: "+ method
  puts "Path: "+ resource
  puts "Version: "+ version
  response = ""
  
  if codigo_waf == "ignorar"
    return codigo_waf
  elsif codigos.key?(codigo_waf)
	  response = method + " " + codigo_waf + " " + codigos[codigo_waf]+"\r\n"
  end

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
    end
  else
    begin
      if method == "GET"
        response = metodo_GET(resource,request,client)
      elsif method == "POST"
        response = metodo_POST(resource,request,client)
      elsif method == "HEAD"
        response = metodo_HEAD(resource,request,client)
      else
        message = "Method not allowed"
        response = "HTTP/1.1 500 Method not allowed\r\n" +
                     "Content-Type: text/html\r\n" +
                     "Content-Length: #{message.size}\r\n" +
                     "Connection: close\r\n" +
                     "\r\n"
                     message
      end
    rescue IOError => e
      puts e
      if e
        message = "File not found\n"
        # Responde con un codigo 404 error que indica que no existe el archivo
        response = "HTTP/1.1 404 Not Found\r\n" +
                   "Content-Type: text/html\r\n" +
                   "Content-Length: #{message.size}\r\n" +
                   "Connection: close\r\n" +
                   "\r\n"
                   message
      end
    end
  end
  return response
end

def parse_headers(request)
  headers = {}
  request.lines[1..-1].each do |line|
    return headers if line == "\r\n"
    header, value = line.split(":")
    headers[header] = value
  end
end

#---------------- Creacion del servidor Web --------------------#
HOSTNAME = '0.0.0.0'
PORT = options[:puerto]

server = TCPServer.new(HOSTNAME, PORT)
puts "Servidor Corriendo en "+HOSTNAME+":"+PORT.to_s
loop do
  # Creamos un hilo por cada cliente que se conecte al Servidor
  Thread.start(server.accept) do |client|
    sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
    request = client.readpartial(2048)
    response = requested_file(client, request,options[:waf], remote_port, remote_ip, options[:audit], ruta_bitacoras)
    if response != "ignorar"
      client.puts response
      client.close
    end
  end
end
