#!/usr/bin/ruby

def waf(archivo, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor)
	begin
		print "IP del cliente: ##########{ip_cliente}\n"
		reglas=File.open(archivo).read
		reglas.each_line do |linea|
			regla,variables,operador,descripcion,accion=linea.match(/(REGLA->[0-9]+);([A-Z_]+[\|A-Z]*);(i?regex:\".+\");(.*);(.*)/).captures
			variables = variables.split("|")
			for var in variables
				variable = obtienevar(var,request,ip_cliente)
				for valor in variable
					codigo = filtra(regla, valor, operador, descripcion, accion, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor)
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


def filtra(regla, var_valor, operador, descripcion, accion, request, puerto_cliente, ip_cliente, puerto_servidor, ip_servidor)
	operador,regex = operador.match(/(i?regex):"(.+)"/).captures
	if operador == "iregex"
		regex = regex.downcase
		var_valor = var_valor.downcase
	end
	if var_valor.match(%[#{regex}])
		cadena = "Timestamp: "+Time.now.to_i.to_s+", IP_Cliente: "+ip_cliente.to_s+", Puerto_Cliente: "+puerto_cliente.to_s+", IP_Server: "+ip_servidor.to_s+", Puerto_Server:"+puerto_servidor.to_s+", Regla: "+regla.split("->")[1]+", Descripcion: "+descripcion+", Request:"+request+"\n"
		writeaudit(cadena)
		return accion
	else
		return ""
	end
end


def writeaudit(cadena)
	path = Dir.pwd + "/audit.log"
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


