#!/usr/bin/ruby

#Modulo que contiene las funciones necesarias para el funcionamiento del Web Application Firewall
#
def waf(archivo, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor, audit_file)
	#Funcion que se manda a llamar cuando el modulo de WAF es activado
	#Recibe: el archivo que contiene las reglas del firewall, el puerto por donde se conecta el cliente, la ip del cliente, el puerto del servidor, la ip del servidor y el archivo donde se va a guardar el archivo de auditoria
	#Devuelve: La respuesta para el cliente, pueden ser codigos HTTP, la cadena "ignorar" o cadena vacia "", dependiendo de estas respuestas se sabe que responder al cliente
	begin
		print "IP del cliente: ##########{ip_cliente}\n"
		reglas=File.open(archivo).read
		reglas.each_line do |linea|
			regla,variables,operador,descripcion,accion=linea.match(/(REGLA->[0-9]+);([A-Z_]+[\|A-Z]*);(i?regex:\".+\");(.*);(.*)/).captures
			variables = variables.split("|")
			for var in variables
				variable = obtienevar(var,request,ip_cliente)
				for valor in variable
					codigo = filtra(regla, valor, operador, descripcion, accion, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor, audit_file)
					if codigo != ""
						if codigo == "ignorar"
							return codigo
						else
							return codigo.split(":")[1]
						end
					end
				end
			end
		end
		return ""
	rescue => e
		printError(e.to_s,true)
	end
end

def obtienevar(var, request, ip_cliente)
	#Funcion que del request obtiene los valores establecidos por var
	#Recibe: var, que es una varible del archivo de reglas, el request completo y la ip del cliente
	#Devuelve, una lista con cero, uno o más elementos, los cuales serán usandos para aplicar el operador del archivo de reglas
	req = request.split("\n")
	regresa=[]
	if var == 'AGENTE_USUARIO'
		for x in req
			if x.include?"User-Agent"
				return [x.split(": ")[1..-1].join(": ").sub("\r","")]
			end
		end

	elsif var == 'METODO'
		return [req[0].split(" ")[0].sub("\r","")]

	elsif var == 'RECURSO'
		return [req[0].split(" ")[1]]

	elsif var == "CUERPO"
		return req[req.index("\r")..-1].map{|word| word.sub("\r","")}

	elsif var == "CLIENTE_IP"
		return [ip_cliente]
	
	elsif var == "CABECERAS_VALORES"
		for x in req[1..req.index("\r")]
			e = x.split(": ")[1..-1].join(": ").sub("\r","")
			regresa.push(e)
		end
		return regresa
	
	elsif var == "CABECERAS_NOMBRES"
		for x in req[1..req.index("\r")]
			e = x.split(": ")[0]
			regresa.push(e)
		end
		return regresa

	elsif var == "CABECERAS"
		for x in req[1..req.index("\r")]
			e = x.sub("\r","")
			regresa.push(e)
		end
		return regresa

	elsif var == "PETICION_LINEA"
		return [req[0].sub("\r","")]

	elsif var == "COOKIES"
		for x in req
			if x.include?"Cookie"
				e = x.split(": ")[1..-1].join(": ").sub("\r","")
				regresa.push(e)
			end
		end
		return regresa

	end
end


def filtra(regla, var_valor, operador, descripcion, accion, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor, audit_file)
	#Funcion que una vez teniendo los valores de las variables aplica el operador del archivo de reglas
	#Recibe: La regla de la siguiente forma: "REGLA->id", el valor de la variable para aplicarle el operador, el operador, la descripcion de la regla, la accion a tomar, el request, el puerto del cliente, la ip del cliente, el puerto del servidor, la ip del servidor y el archivo de auditoria, estos ultimos datos son importantes ya que se manda a llamar a la funcion que escribe en el archivo de auditoria y con ellos se arma el mensaje para pasarsela 
	#Devuelve: La accion a tomar, osea ,lo que se le va a responder al cliente. 
	operador,regex = operador.match(/(i?regex):"(.+)"/).captures
	if operador == "iregex"
		regex = regex.downcase
		var_valor = var_valor.downcase
	end
	if var_valor.match(%[#{regex}])
		cadena = "Timestamp: "+Time.now.to_i.to_s+", IP_Cliente: "+ip_cliente.to_s+", Puerto_Cliente: "+puerto_cliente.to_s+", IP_Server: "+ip_servidor.to_s+", Puerto_Server:"+puerto_servidor.to_s+", Regla: "+regla.split("->")[1]+", Descripcion: "+descripcion+", Request:\n"+request+"\n"
		writeaudit(cadena, audit_file)
		return accion
	else
		return ""
	end
end


def writeaudit(cadena, audit_file)
	#Funcion que escribe en el archivo de auditoria del WAF
	#Recibe: La cadena a escribir en el archivo, y el nombre del archivo
	path = Dir.pwd + "/" + audit_file
	File.write(path,cadena,mode:'a')
end


def verifica_reglas(reglas)
	acciones_validas = ["codigo:403", "codigo:404", "codigo:500", "ignorar"]
	ids=[]
	reglas=File.open(reglas).read
	reglas.each_line do |regla|
		x = regla.split(";")[0].split("->")[1]
		r,v,o,d,accion=regla.match(/(REGLA->[0-9]+);([A-Z_]+[\|A-Z]*);(i?regex:\".+\");(.*);(.*)/).captures
		if ids.include?x
			printError("Error en el archivo de reglas, la regla con id: "+x+ " se repite", true)
		else
			ids.push(x)
		end
		if !acciones_validas.include?accion
			cadena = "La accion (" +accion +") en: "+r+ " no esta permitida, las acciones permitidas son:\n"+acciones_validas.join("\n")
			printError(cadena, true)
		end
	end

end


def printError(mensaje,ex=false)
	print("\nError: "+mensaje+"\n")
	if ex
		exit
	end
end	


