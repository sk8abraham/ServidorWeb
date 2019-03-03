#!/usr/bin/ruby

IP_Cliente = "127.0.0.1"
Puerto_Cliente = "12345"

IP_Server = "0.0.0.0"
Puerto_Server = "8080"


def waf(archivo, request)
	begin
		reglas=File.open(archivo).read
		reglas.each_line do |linea|
			regla,variables,operador,descripcion,accion=linea.match(/(REGLA->[0-9]+);([A-Z_]+[\|A-Z]*);(i?regex:\".+\");(.*);(.*)/).captures
			variables = variables.split("|")
			for var in variables
				variable = obtienevar(var,request)
				for valor in variable
					codigo = filtra(regla, valor, operador, descripcion, accion, request)
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
		print "lol"
		return ""
	rescue => e
		printError(e.to_s,true)
	end
end

def obtienevar(var, request)
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
		#print "clienteip: \n"
		return [IP_Cliente]
	
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


def filtra(regla, var_valor, operador, descripcion, accion, request)
	operador,regex = operador.match(/(i?regex):"(.+)"/).captures
	if operador == "iregex"
		regex = regex.downcase
		var_valor = var_valor.downcase
	end
	if var_valor.match(%[#{regex}])
		cadena = "Timestamp: "+Time.now.to_i.to_s+", IP_Cliente: "+IP_Cliente+", Puerto_Cliente: "+Puerto_Cliente+", IP_Server: "+IP_Server+", Puerto_Server:"+Puerto_Server+", Regla: "+regla.split("->")[1]+", Descripcion: "+descripcion+", Request:"+request+"\n"
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


pet="GET / HTTP/1.1\nHost: localhost:8080\nUser-Agent: curl/7.52.1\nCookie: qwerty\nAccept: */*\n\r"
#verifica_reglas("reglas.txt")
codigo = waf("reglas.txt",pet)
print "Codigo: #{codigo}\n"


