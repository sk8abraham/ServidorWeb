#!/usr/local/bin/perl
print "Content-type: text/html", "\n\n";
print "<html>", "\n";
print "<head><tittle>About this Server</tittle></head>", "\n";
print "<body><h1>About this Server</h1>", "\n";
print "<hr><pre>";
print "Server Name:      ", $ENV{'SERVER_NAME'}, "<br>", "\n";
print "Running on Port:  ", $ENV{'SERVER_PORT'}, "<br>", "\n";
print "Server Software:  ", $ENV{'SERVER_SOFTWARE'}, "<br>", "\n";
print "Server Protocol:  ", $ENV{'SERVER_PROTOCOL'}, "<br>", "\n";
print "CGI Revision:     ", $ENV{'GATEWAY_INTERFACE'}, "<br>", "\n";
print "Request URL:      ", $ENV{'REQUEST_URI'}, "<br>", "\n";
print "Query String:      ", $ENV{'QUERY_STRING'}, "<br>", "\n";
print "Document Root:    ", $ENV{'DOCUMENT_ROOT'}, "<br>", "\n";
print "Request Method:   ", $ENV{'REQUEST_METHOD'}, "<br>", "\n";
print "Remoto Address:   ", $ENV{'REMOTE_ADDR'}, "<br>", "\n";
print "Remoto Port:      ", $ENV{'REMOTE_PORT'}, "<br>", "\n";

print "User Agent:       ", $ENV{'HTTP_USER_AGENT'}, "<br>", "\n";
print "HTTP COOKIE:      ", $ENV{'HTTP_COOKIE'}, "<br>", "\n";
print "HTTP Referer:     ", $ENV{'HTTP_REFERER'}, "<br>", "\n";

print "<hr></pre>", "\n";
print "</body></html>", "\n";
exit (0);