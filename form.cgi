#!/usr/bin/python

import cgi, cgitb
cgitb.enable()

form = cgi.FieldStorage()

# Obtenemos datos
nombre = form.getvalue('nombre')
no_cta = form.getvalue('no_cta')


print("Content-type:text/html\r\n\r\n")
print("<html>")
print("<head><title>Usuario introducido</title></head>")
print("<body>")
print("<h1>El usuario introducido es:</h1>")
print("<b>Nombre : </b>" + nombre + "<br>")
print("<br><b>No de cuenta : </b>" + str(no_cta) + "<br>")
print("")
print("</div>")
print("</body>")
print("</html>")
