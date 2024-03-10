<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<%@include file="includes/header.inc"%>
<%!
String jspname = gamename + "/main.jsp";
String filter_type = "wml";
String title = gamename_cn;

String read(InputStream reader) throws IOException{
	BufferedReader r = new BufferedReader(new InputStreamReader(reader,"UTF-8"));
	String ret ="";
	int n;
	try{
		char buff[]=new char[4096];
		n=r.read(buff,0,4096);
		while(n!=-1){
			ret += new String(buff,0,n);
		n=r.read(buff,0,4096);
		}
	}catch(Exception e){
		e.printStackTrace();
	}
	return ret;
}
%>  
<%
long startTime = System.currentTimeMillis(); 
try{
	String hostStr = request.getHeader("Host");
	if(internet_ip.equals(hostStr)||internet_addr.equals(hostStr)){
		response.sendRedirect(index_url+"?"+paraString);	
		return;
	}
	String _ip = (String)request.getRemoteAddr();
	
	//������������ʱ�򣬽��û��ر�����Ϸ��
	if((!(_ip.equals(our_ip)))&&game_close==1)
		response.sendRedirect("./post.jsp?ip="+_ip);

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

String regnewFlag = (String)request.getParameter("regnewFlag");
String game_fg = (String)request.getParameter("game_fg");
String SID = (String)isession.getId();
//����ע��/////////////////////////////////////////
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
//�򵥼����û���������
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
//�����û���Ҫִ�е�ָ��
String cmd=request.getParameter("_cmd");
if(cmd!=null){
	cmd = cmd.trim();
	if(cmd.length()>2)
		cmd = "look";
}

String arg=request.getParameter("_arg");
String temptitle=new String(title.getBytes("ISO8859-1"),"UTF-8");
//���������ε����Լ�wap�����û�
try
{
	String _ip = (String)request.getRemoteAddr();
        request.setCharacterEncoding("utf-8"); 
	if((isComputer(request)&&!(_ip.equals(our_ip)))
	||_ip.equals("222.214.218.85")
	||_ip.equals("211.95.176.6")
	||_ip.equals("222.73.236.4")
	||_ip.equals("125.77.73.133")   
	||_ip.equals("125.77.75.28") 
	||_ip.equals("222.76.88.140")
	||_ip.equals("59.151.46.183")
	||_ip.equals("222.76.86.153")
	||_ip.equals("221.130.197.84")
	||_ip.equals("218.83.155.166")
	||_ip.equals("59.61.124.189")
	||_ip.equals("221.130.197.84")  
	||_ip.equals("59.151.46.183") 
	||_ip.equals("222.76.89.134")   
	||_ip.equals("125.77.81.179")
	||_ip.equals("219.133.59.158") 
	||_ip.equals("61.145.116.10")
	||_ip.equals("125.77.80.239")
	||_ip.equals("222.76.88.176"))
	{
		response.sendRedirect("./notMobile.jsp?ip="+_ip);
		return;
	}
}catch(Exception uae)
{
	com.lj.bbs.tools.setDefaultCharSet(request);
	System.out.println("[ua exception]"+uae+"\n"); 
}


//�������socket�ĳ�ʼ��
Socket socket;
InputStream reader;
OutputStream writer;
socket = new Socket(ip,port);
reader = socket.getInputStream();
writer = socket.getOutputStream();
//��ʼ����ָ��
//��һ����Ҳ��ÿ�ζ�Ҫ���͵�ָ��
send(writer,("set_filter "+filter_type+" "+response.encodeURL("/"+jspname)+" "+temptitle).getBytes("gb2312"));

if(first_login){//�״ε�½
	long ot = System.currentTimeMillis();
	Long time_ot = new Long(ot);
	isession.setAttribute("ot",time_ot);

	String _reg = (String)request.getParameter("_reg");
	
	if(_reg!=null&&_reg.equals("1")){//����ע��
		String _sid = (String)request.getParameter("_sid");
		send(writer,("login_check "+projname+" "+userid+" "+passwd+" "+_sid).getBytes());
	}
	else{//���û���¼
		String userSessionID = (String)isession.getId();
		send(writer,("login_check "+projname+" "+userid+" "+passwd+" "+userSessionID).getBytes());
	}
}
else{//���״ε�½����Ҫ�ж���������
	Long otTmp = (Long)isession.getAttribute("ot");
	if(otTmp==null){
		long ot2 = System.currentTimeMillis()-1550;
		Long time_ot2 = new Long(ot2);
		otTmp = time_ot2;
		isession.setAttribute("ot",time_ot2);
	}
	long nt = System.currentTimeMillis();
	Long time_nt = new Long(nt);
	long otime = otTmp.longValue();
	long ntime = time_nt.longValue();
	long diffTime = ntime - otime; 
	if(diffTime<=1500){//������죬�Զ�ִ��lookָ��
		isession.setAttribute("ot",time_nt);
		cmd="look";
	}else
		isession.setAttribute("ot",time_nt);
		
	//ģ���û���¼
	send(writer,("login "+projname+" "+uid+" "+pid+" "+usid).getBytes());
}

if(first_login){//����û����״ε�½����Ҫ��¼sid��m_key
	String sid="tmpUser";
	send(writer,("set_sid "+sid).getBytes());//�����û���sid 

	String m_key=(String)request.getParameter("_mkey");
	if(m_key != null)
		send(writer,("set_mkey "+m_key).getBytes());//�����û���m_key
	send(writer,("set_game_fg "+game_fg).getBytes());//������ҵ���Ϸ����ʶ
}

if(cmd!=null&&cmd.equals("quit"))//�������Ϊquit,������������Ƽ�ʱ
{
	isession.removeAttribute("ot");
}

if(cmd==null)cmd="init";

//��������Ͳ����е������ַ�
boolean have_space=false;
for(Enumeration en=request.getParameterNames();en.hasMoreElements();){
	String name = (String)en.nextElement();
	String value = request.getParameter(name);
	//�����ƶ����Ӳ���t
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
send(writer,"flush_filter".getBytes());//flush_filter.pike->�رո�conn����
socket.shutdownOutput();
data=read(reader);

try{
	if(writer!=null) writer.close();
	if(reader!=null) reader.close();
	if(socket!=null) socket.close();
}catch(Exception e){
	logger_pv.error("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]",e);
} 
	logger_pv.debug("[uid:"+uid+"] [cmd:" + cmd+ "] [" +  (System.currentTimeMillis()-startTime)+"ms]"); 
	response.setContentType("text/vnd.wap.wml;charset=UTF-8");
%>

<%=data%>
