<%@include file="includes/header.inc"%>
<%!
String jspname = gamename+"/manager.jsp";
String filter_type="html5";
String title=gamename_cn+"管理后台";

String read(InputStream reader) throws IOException
{
	BufferedReader r = new BufferedReader(new InputStreamReader(reader,"gb2312"));
	String s = "";
	String ret ="";
	int n;
	try{
		s=r.readLine();
		while(s!=null&&!s.equals("")){//这段while代码读起来很诡异，但是如果去掉，会在游戏页面最上方出现一行多余的字符
			int i;
			for(i=0;i<s.length()&&s.charAt(i)!='|';i++);
			if(i!=s.length()){}
			s=r.readLine();
		}
		char buff[]=new char[4096];
		n=r.read(buff,0,4096);
		while(n!=-1){
			ret+=new String(buff,0,n);
			n=r.read(buff,0,4096);
		}
	}catch(Exception e)
	{
		e.printStackTrace();
	}
	return ret;
}
%>
<%
	try{
		String _ip = (String)request.getRemoteAddr();
		com.lj.bbs.tools.setDefaultCharSet(request);
	}catch(Exception uae){
		request.setCharacterEncoding("utf-8");
	}
	String data=null;

	HttpSession isession=null;
	isession = request.getSession();

	Socket socket;
	InputStream reader;
	OutputStream writer;

	socket = new Socket(ip,port);
	reader = socket.getInputStream();
	writer = socket.getOutputStream();

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

	if(userid!=null&&passwd!=null)//第一次从entry.jsp登陆，有_user和_pswd
	{
		uid = userid;
		pid = passwd;
		first_login = true;
	}
	if(txd!=null&&!txd.equals("")&&!txd.equals(" "))
	{
		String stru="";
		String strp="";
		int i=0;
		for(i=0;i<txd.length()&&txd.charAt(i)!='~';i++);
		if(i!=txd.length()){
			stru = txd.substring(0,i);
			strp = txd.substring(i+1,txd.length());
		}
		uid = stru;
		pid = strp;
	}

	String cmd=request.getParameter("_cmd");
	String arg=request.getParameter("_arg");
	String game_fg = (String)request.getParameter("game_fg");  
	String temptitle=new String(title.getBytes("ISO8859-1"),"gb2312");
//第一条，也是每次都要发送的指令
	send(writer,("set_filter "+filter_type+" "+response.encodeURL("/"+jspname)+" "+temptitle).getBytes("gb2312"));

	if(first_login){
		String userSessionID = (String)isession.getId();
		send(writer,("login_check "+projname+" "+game_fg+userid+" "+passwd+" "+userSessionID).getBytes());
	}
	else
	send(writer,("login "+projname+" "+uid+" "+pid+" "+usid).getBytes());

	if(first_login){
		String sid="hihi";
		send(writer,("set_sid "+sid).getBytes());
		send(writer,("set_game_fg "+game_fg).getBytes());//合区调用
	}	
	if(cmd==null)cmd="init";
	
	boolean have_space=false;
	for(Enumeration en=request.getParameterNames();en.hasMoreElements();){
		String name = (String)en.nextElement();
		String value = request.getParameter(name);
		if(name.charAt(0)!='_'&&(name.length()<5)){
			cmd+=name+"=";
			for(int i=0;i<value.length();i++){
				if(value.charAt(i)==' ')
					cmd+="%20";
				else if(value.charAt(i)=='%')
					cmd+="%%";
				else
					cmd+=value.substring(i,i+1);
			}
			cmd+=" ";
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
		cmd=cmd.substring(0,cmd.length()-1);

	send(writer,cmd.getBytes("gb2312"));
	send(writer,"flush_filter".getBytes());//flush_filter.pike->关闭该conn对象
	socket.shutdownOutput();

	data=read(reader);

	if(writer!=null) writer.close();
	if(reader!=null) reader.close();
	if(socket!=null) socket.close();

	response.setContentType("text/html; charset=gb2312");
	%>
	<%=data%>

