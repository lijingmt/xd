<%@include file="includes/header.inc"%>
<%!
String jspname = gamename + "/main_ft.jsp";
String filter_type = "html6";
String title = gamename_cn;

String read(InputStream reader) throws IOException
{
    /*
	//BufferedReader r = new BufferedReader(new InputStreamReader(reader,"UTF-8"));
    BufferedReader r = new BufferedReader(new InputStreamReader(reader,"gb2312"));
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
	*/
    BufferedReader r = new BufferedReader(new InputStreamReader(reader,"gb2312"));
    String ret ="";
    String s = "";
	int n;
	try{
		s=r.readLine();
		while(s!=null&&!s.equals("")){//这段while代码读起来很诡异，但是如果去掉，会在游戏页面最上方出现一行多余的字符
			int i;
			for(i=0;i<s.length()&&s.charAt(i)!='|';i++);
			if(i!=s.length()){
			}
			s=r.readLine();
		}
		char buff[]=new char[4096];
		n=r.read(buff,0,4096);
		//System.out.println("s=["+s+"]\n");
		while(n!=-1){
			ret+=new String(buff,0,n);
			n=r.read(buff,0,4096);
		}
		//System.out.println("ret=["+ret+"]\n");
	}
	catch(Exception e){
		e.printStackTrace();
	}
	return ret;
}
%>  
<%
long startTime = System.currentTimeMillis(); 
try{
	//request.setCharacterEncoding("UTF-8");
	request.setCharacterEncoding("gbk");
}catch(Exception uae){
    //com.lj.bbs.tools.setDefaultCharSet(request);
    //System.out.println("[ua exception]"+uae+"\n");
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
//新手注册/////////////////////////////////////////
String regnewFlag = (String)request.getParameter("regnewFlag");
String game_fg = (String)request.getParameter("game_fg");
String SID = (String)isession.getId();
if(regnewFlag!=null&&regnewFlag.equals("1"))
	response.sendRedirect("./login_reg.jsp?_user="+userid+"&_pswd="+passwd+"&sid="+SID+"&"+paraString);
///////////////////////////////////////////////////
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
/*
if(cmd!=null){
	cmd = cmd.trim();
	if(cmd.length()>4)
		cmd = "look";
}
*/
String arg=request.getParameter("_arg");
String temptitle=new String(title.getBytes("ISO8859-1"),"UTF-8");
//这里再进行socket的初始化
Socket socket;
InputStream reader;
OutputStream writer;
socket = new Socket(ip,port);
reader = socket.getInputStream();
writer = socket.getOutputStream();
//第一条，也是每次都要发送的指令
send(writer,("set_filter "+filter_type+" "+response.encodeURL("/"+jspname)+" "+temptitle).getBytes("gb2312"));
//send(writer,("set_filter "+filter_type+" "+response.encodeURL("/"+jspname)+" "+"xdtest").getBytes("utf-8"));
if(first_login){
	String _reg = (String)request.getParameter("_reg");
	///////新手注册/////////////////
	if(_reg!=null&&_reg.equals("1")){
		String _sid = (String)request.getParameter("_sid");
		send(writer,("login_check "+projname+" "+userid+" "+passwd+" "+_sid).getBytes());
	}
	else{
		//////////老用户登录////////////////
		String userSessionID = (String)isession.getId();
		send(writer,("login_check "+projname+" "+userid+" "+passwd+" "+userSessionID).getBytes());
	}
}
else{
	send(writer,("login "+projname+" "+uid+" "+pid+" "+usid).getBytes());
}	
if(first_login){
	String sid="tmpUser";
	send(writer,("set_sid "+sid).getBytes());

	String m_key=(String)request.getParameter("_mkey");
	if(m_key != null)
		send(writer,("set_mkey "+m_key).getBytes());
	send(writer,("set_game_fg "+game_fg).getBytes());//合区调用
}
if(cmd==null)
	cmd="init";
boolean have_space=false;
String _arg="";//request.getParameter("_arg");
for(Enumeration en=request.getParameterNames();en.hasMoreElements();){
	String name = (String)en.nextElement();
	String value = request.getParameter(name);
	//屏蔽移动所加参数t
if("t".equals(name))
		continue;
////////////////////////
if("arg".equals(name))
	continue;
if("_arg".equals(name))
	_arg = " "+value;
////////////////////////
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
	//_arg = new String((_arg).getBytes("gb2312"));
	cmd=cmd+_arg;
}
	
	//send(writer,cmd.getBytes("UTF-8"));
send(writer,cmd.getBytes("gb2312"));
send(writer,"flush_filter".getBytes());//flush_filter.pike->关闭该conn对象
socket.shutdownOutput();
data=read(reader);
try{
if(writer!=null) writer.close();
if(reader!=null) reader.close();
if(socket!=null) socket.close();
}catch(Exception e){
       // System.out.println("[socket exception]"+e+"\n");
        //logger_pv.error("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]",e);
} 
//logger_pv.debug("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]"); 
//response.setContentType("text/vnd.wap.wml;charset=gb2312");
//response.setContentType("text/html; charset=gb2312");
response.setContentType("text/html;charset=UTF-8");
//response.setContentType("text/html; charset=gb2312");
data=ZHConverter.convert(data,ZHConverter.TRADITIONAL);
%><%=data%>
