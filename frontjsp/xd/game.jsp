<%@include file="includes/header.inc"%> 
<%!
String jspname = "game.jsp";
String filter_type = "html";
String title = gamename_cn;
String read(InputStream reader) throws IOException
{
    BufferedReader r = new BufferedReader(new InputStreamReader(reader,"gb2312"));
    String ret ="";
    String s = "";
	int n;
	try{
		s=r.readLine();
		while(s!=null&&!s.equals("")){
			int i;
			for(i=0;i<s.length()&&s.charAt(i)!='|';i++);
			if(i!=s.length()){
			}
			s=r.readLine();
		}
		char buff[]=new char[4096];
		n=r.read(buff,0,4096);
		while(n!=-1){
			ret+=new String(buff,0,n);
			n=r.read(buff,0,4096);
		}
	}
	catch(Exception e){
		e.printStackTrace();
	}
	return ret;
}

%> 
<%
try{
	request.setCharacterEncoding("gbk");
}catch(Exception uae){
    	System.out.println("[ua exception]"+uae+"\n");
}
String data=null;
response.addHeader("Expires","Mon, 26 Jul 1997 05:00:00 GMT");
response.addHeader("Last-Modified","2004:08:05"+"GMT");	
response.addHeader("Cache-Control","no-cache, must-revalidate");
response.addHeader("Pragma","no-cache");
String infos=(String)request.getParameter("info");
String txd="";
String cmd="";
if(infos!=null&&!infos.equals("")&&!infos.equals(" ")){
	String[] strArray = infos.split("\\|");
	if(strArray.length==2){
		txd = strArray[0];
		cmd = strArray[1];
	}
	else{
		String[] strArray2 = infos.split("\\,");
		if(strArray2.length==2){
			txd = strArray2[0];
			cmd = strArray2[1];
		}
	}
}
if(!cmd.equals("null")&&cmd!=null){
	cmd = cmd.trim();
}
else
	cmd = "init";
String arg=request.getParameter("arg");
String temptitle=new String(title.getBytes("ISO8859-1"),"UTF-8");
Socket socket;
InputStream reader;
OutputStream writer;
socket = new Socket(ip,port);
reader = socket.getInputStream();
writer = socket.getOutputStream();
send(writer,("set_filter "+filter_type+" "+response.encodeURL("./"+jspname)+" "+temptitle).getBytes("gb2312"));
send(writer,("login_des_p "+projname+" "+txd).getBytes());
if(cmd.equals("init")){
	send(writer,("set_sid okay").getBytes());
	send(writer,("set_game_fg "+area).getBytes());
}
boolean have_space=false;
String _arg="";
for(Enumeration en=request.getParameterNames();en.hasMoreElements();){
	String name = (String)en.nextElement();
	String value = request.getParameter(name);
if("t".equals(name))
	continue;
if("info".equals(name))
	continue;
if("arg".equals(name))
	continue;
if("_arg".equals(name))
	_arg = " "+value;
	if(name.charAt(0)!='_'&&(name.length()<5)){
		cmd+=" "+name+"=";
		for(int i=0;i<value.length();i++){
			if(value.charAt(i)==' ')
				cmd+="%20";
			else if(value.charAt(i)=='%')
				cmd+="%%";
			else
				cmd+=value.substring(i,i+1);
		}
		have_space=true;
	}
}
if(arg!=null){
	String t_cmd="";
	for(int i=0;i<arg.length();i++){
		if(arg.charAt(i)==' ')
			t_cmd+="%20";
		else if(arg.charAt(i)=='%')
			t_cmd+="%%";
		else
			t_cmd+=arg.substring(i,i+1);
	}
	cmd=cmd+" "+t_cmd;
	cmd=cmd.replaceAll("  "," ");
}
else if(have_space)
	cmd=cmd.trim();
if(_arg!=null){
	cmd=cmd+_arg;
}
send(writer,cmd.getBytes("gb2312"));
send(writer,"flush_filter".getBytes());
socket.shutdownOutput();
data=read(reader);
try{
if(writer!=null) writer.close();
if(reader!=null) reader.close();
if(socket!=null) socket.close();
}catch(Exception e){
       System.out.println("[socket exception]"+e+"\n");
} 
response.setContentType("text/html; charset=gb2312");
%><%=data%>
