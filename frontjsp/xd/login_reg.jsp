<!DOCTYPE html>
<html>
<head>
<%@ page language="java" contentType="text/html;charset=UTF-8"%>
<%@include file="includes/header.inc"%>
	<meta charset="UTF-8">
	<meta name="viewport" content="maximum-scale=1.0,minimum-scale=1.0,user-scalable=0,width=device-width,initial-scale=1.0"/>
<title>《天下仙道网游》[一区]</title>
<link href="includes/intro.css" rel="stylesheet" type="text/css"/>
</head>
<body>
<div>
	<!DOCTYPE html>
	<html lang="zh-cn">
		<head>
			<meta charset="UTF-8">
			<meta name="viewport" content="maximum-scale=1.0,minimum-scale=1.0,user-scalable=0,width=device-width,initial-scale=1.0"/>
			<title>《天下仙道网游》[一区]</title>
			<link href="includes/bootstrap.min.css" rel="stylesheet">
			<style>
				body {
					font: Normal 18px "Arial Black";
					text-align: center;
				}
				@media (min-width: 768px) {
					body {
						margin: 0 auto;
						width: 414px;
					}
				}
				.logo {
					margin-top: 5px;
					width: 240px;
					height: 64px;
				}
				.form-group{
					width:90%;
					margin:5%;
				}
				.lable{
					width:60px;
					font-size: 16px;
					font-weight: 500;
					text-align: center;
				}
				.input{
					width:calc(100% - 80px);
					font-size: 16px;
				}
				.desc{
					width: 90%;
					margin: 5%;
				}
				.copyright{
					margin-top:30px;
				}
				.btns{
					margin-top:30px;
				}
				.btn{
					margin: 0 20px;
				}
				h2{
					font-size:20px;
				}
			</style>
		</head>
	<body>

			<img src="logo.png" class="logo">
<%
  String z = (String)request.getParameter("z");
if(z==null)
	z=(String)request.getSession().getAttribute("z");
	else
	request.getSession().setAttribute("z",z);
	String user = request.getParameter("_user");
	String pswd = request.getParameter("_pswd");
	String regnewFlag = (String)request.getParameter("regnewFlag");  
	String m_key = (String)request.getParameter("m_key");
	String mid= (String)request.getParameter("mid");
	String from= (String)request.getParameter("from");
	String ap_info= (String)request.getParameter("ap_info");
	String userip = (String)request.getRemoteAddr();
	//String userip = "192.158.13.252";
	String userua = (String)request.getHeader("User-Agent");
	//String userua = "UserAgent";
	String user_url = java.net.URLEncoder.encode(user,"UTF-8");
	String pswd_url = java.net.URLEncoder.encode(pswd,"UTF-8");
if( user==null || pswd==null){
	//out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
	response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=1&"+paraString);
}
else{
	user = user.trim();
	pswd = pswd.trim();
	if(user.length() == 0 || pswd.length() == 0){
		//	out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=1&"+paraString);
	}
	else if( user.length()<2 || pswd.length()<2 ){
		//out.print("|"+user + "|:|" + pswd + "|<br/>");
		//out.print("为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");	
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=2&"+paraString);
	}
	else if( user.length()>11 || pswd.length()>11 ){
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=5&"+paraString);
	}
	else{	
		String user_pswd = user + pswd;
		if(!isLegalChar(user_pswd)){
			response.sendRedirect("./regnew.jsp?_user="+user_url+"&_pswd="+pswd_url+"&err=3&"+paraString);
		}
		else {
			Socket socket = new Socket(ip,port);
			InputStream reader = socket.getInputStream();
			OutputStream writer = socket.getOutputStream();

			String sid = (String)session.getId();

			send(writer,("login_regnew "+projname+" "+user+" "+pswd+" "+sid+" "+game_pre+" "+m_key+" "+userip+" "+userua).getBytes());
			send(writer,"flush_filter".getBytes());
			socket.shutdownOutput();

			String ret = read(reader,"utf-8");

			if(writer!=null) writer.close();
			if(reader!=null) reader.close();
			if(socket!=null) socket.close();

			if(ret.equals("error1")){
				//resultData += "游戏帐号已经有人使用！<br/>";
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=4&"+paraString);
			}
			else if(ret.equals("error2")){
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=5&"+paraString);
			}
			else{
				String resultData = "<h2>注册成功</h2>";
				
				String stru="";
				String strp="";

				int i=0;
				for(i=0;i<ret.length()&&ret.charAt(i)!=',';i++)
					;
				if(i!=ret.length())
				{
					stru = ret.substring(0,i);
					strp = ret.substring(i+1,ret.length());
				}
				resultData += "<h4 class=\"desc\">帐号："+stru+"</h4>";
				resultData += "<h4 class=\"desc\">密码："+strp+"</h4>";
				//out.print("<a href=\"./main.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">play game now</a><br/>");
				resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\"./main.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">进入游戏（简体）</a><br/>";
				resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\"./main_ft.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">進入遊戲（繁體）</a><br/>";
				//resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\"./main_dark.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">进入游戏（简体）黑暗模式</a><br/>";
				//resultData += "<a class=\"btn btn-danger btn-lg\" style=\"margin-top:10px;\" href=\"./main_ft_dark.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">進入遊戲（繁體）黑暗模式</a><br/>";
				resultData += "<h4 class=\"text-success\">最新通告(2022-02-22)</h4>";
				resultData += "<h5 class=\"text-success\">1.充值就送大礼！(详情参见游戏内说明)</h5>";
				resultData += "<h5 class=\"text-success\">2.日常技能任务开放，不用辛苦刷技能经验了！</h5>";
				resultData += "<h5 class=\"text-success\">3.节前开放一批新宝库、声望装备！boss也会掉噢！</h5>";
				out.println(resultData);
			}
		}
	}
}
%>
		<br/>
		<h6 class="text-danger">本游戏仅在非中国地区运营，请遵守本地法律使用本游戏服务<br/></h6>
		<h6 class="text-danger">版权所有 2022  天下团队 地点日本美国<br/></h6>
		<br/>
		<h4 class="copyright">© 2022 《天下仙道网游》<br/><br/><a href="./pc.jsp">返回首页</a></h4>
		</body>
		<script src="includes/jquery.min.js"></script>
		<script src="includes/bootstrap.min.js"></script>
		</html>
</body>
<script src="includes/translate.js"></script><script>translate.language.setLocal('chinese_simplified'); translate.service.use('client.edge'); translate.setAutoDiscriminateLocalLanguage();translate.execute();</script>
</html>
