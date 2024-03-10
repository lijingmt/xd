<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<%@include file="includes/header.inc"%>
<%!
String jspname=gamename+"/demo.jsp";
String filter_type="wml";
String title="仙道游客试玩";
String read(InputStream reader) throws IOException
{
    BufferedReader r = new BufferedReader(new InputStreamReader(reader,"UTF-8"));
	String ret ="";
	int n;
	try{
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
long startTime = System.currentTimeMillis(); 
String _ip = (String)request.getRemoteAddr();
try{

/*
	String ua=request.getHeader("User-Agent");
	if(ua!=null){
		response.sendRedirect("./notMobile.jsp");
		return;
	}
	if(_ip.equals("219.142.232.151"))
	   ;
	   else
	   response.sendRedirect("./post.jsp");
*/
}catch(Exception uae){
	System.out.println("[via]"+uae+"\n");
}
try{
	request.setCharacterEncoding("utf-8");
}catch(Exception uae){
	com.lj.bbs.tools.setDefaultCharSet(request);
	System.out.println("[ua exception]"+uae+"\n");
}
String data=null;
HttpSession isession=null;
isession = request.getSession();
response.addHeader("Expires","Mon, 26 Jul 1997 05:00:00 GMT");
response.addHeader("Last-Modified","2004:08:05"+"GMT");	
response.addHeader("Cache-Control","no-cache, must-revalidate");
response.addHeader("Pragma","no-cache");
String userid = (String)request.getParameter("_user");
String passwd = (String)request.getParameter("_pswd");
String txd=(String)request.getParameter("_txd");
String usid=(String)request.getParameter("_usid");
String uid="";
String pid="";
boolean first_login=false;
if(userid!=null&&passwd!=null){
	uid = userid;
	pid = passwd;
	first_login = true;
}
if(txd!=null&&!txd.equals("")&&!txd.equals(" ")){
	String stru="";
	String strp="";
	int i=0;
	for(i=0;i<txd.length()&&txd.charAt(i)!='~';i++)
		if(i!=txd.length()){
			stru = txd.substring(0,i+1);
			strp = txd.substring(i+2,txd.length());
		}
	uid = stru;
	pid = strp;
}
String cmd=request.getParameter("_cmd");
if(cmd!=null){
	cmd = cmd.trim();
	if(cmd.length()>2)
		cmd = "look";
}
String arg=request.getParameter("_arg");
String temptitle=new String(title.getBytes("ISO8859-1"),"gb2312");
//这里再进行socket的初始化
Socket socket;
InputStream reader;
OutputStream writer;
socket = new Socket(ip,port);
reader = socket.getInputStream();
writer = socket.getOutputStream();
//第一条，也是每次都要发送的指令
send(writer,("set_filter "+filter_type+" "+response.encodeURL("/"+jspname)+" "+temptitle).getBytes("gb2312"));
if(first_login){	
	String userSessionID = (String)isession.getId();
	send(writer,("login_check_intro "+projname+" "+userid+" "+passwd+" "+userSessionID).getBytes());
}
else
send(writer,("login_intro "+projname+" "+uid+" "+pid+" "+usid).getBytes());
if(first_login){
	String sid="5dwap";
	send(writer,("set_sid "+sid).getBytes());
	//推广字段///////////////////////////////////
	send(writer,("set_mid"+" "+userid).getBytes());
	send(writer,("set_mkey"+" "+passwd).getBytes());
	//推广字段///////////////////////////////////
}
if(cmd==null)
	cmd="init";
	boolean have_space=false;
	for(Enumeration en=request.getParameterNames();en.hasMoreElements();){
		String name = (String)en.nextElement();
		String value = request.getParameter(name);
		//屏蔽移动所加参数t
		if("t".equals(name))
			continue;
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
	send(writer,cmd.getBytes("UTF-8"));
	send(writer,"flush_filter".getBytes());//flush_filter.pike->关闭该conn对象
	socket.shutdownOutput();
	data=read(reader);
	try{
		if(writer!=null) writer.close();
		if(reader!=null) reader.close();
		if(socket!=null) socket.close();
	}catch(Exception e){
		//System.out.println("[socket exception]"+e+"\n");
		//logger.error("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]",e);
	} 
response.setContentType("text/vnd.wap.wml;charset=UTF-8");
//logger.debug("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]"); 
%><%=data%>
