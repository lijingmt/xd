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
					font: Normal 18px "Noto Sans SC Medium";
					text-align: center;
					background:lightyellow;
  					color: #A6A6A6;
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
  <%
  String z = (String)request.getParameter("z");

if(z==null)
	z=(String)request.getSession().getAttribute("z");
	else
	request.getSession().setAttribute("z",z);

	String user = request.getParameter("_user");
	String pswd = request.getParameter("_pswd");
	String regnewFlag = (String)request.getParameter("regnewFlag");  
	String game_fg = (String)request.getParameter("game_fg");  

	 String m_key = (String)session.getAttribute("m_key");   


if( user==null || pswd==null)
{
	//out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
	response.sendRedirect("./pc.jsp?err=1");
}
else
{
	user = user.trim();
	pswd = pswd.trim();

	String user_url = java.net.URLEncoder.encode(user,"UTF-8");
	String pswd_url = java.net.URLEncoder.encode(pswd,"UTF-8");

	if(user.length() == 0 || pswd.length() == 0)
	{
		//	out.print("|"+user + "|:|" + pswd + "|<br/>");
		//	out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
		response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=1");
	}
	else if( user.length()<2 || pswd.length()<2 )
	{
		//out.print("|"+user + "|:|" + pswd + "|<br/>");
		//out.print("为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");	
		response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=2");
	}
	else if( user.length()>12 || pswd.length()>12 )
	{
		//resultData += "游戏账号和密码必须是2~12位的英文或者数字，或者两者的组合<br/>";
		response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=5");
	}
	else
	{	
		String user_pswd = user + pswd;

		if(!isLegalChar(user_pswd))
		{
			//out.print("|"+user + "|:|" + pswd + "|<br/>");
			//out.print("用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");	
			response.sendRedirect("./pc.jsp?_user="+user_url+"&_pswd="+pswd_url+"&err=3");
		}
		else 
		{
			Socket socket = new Socket(ip,port);
			InputStream reader = socket.getInputStream();
			OutputStream writer = socket.getOutputStream();

			String sid = (String)session.getId();
			String user_new = game_fg+user;
			send(writer,("login_check5 "+projname+" "+user_new+" "+pswd+" "+sid).getBytes());
			send(writer,"flush_filter".getBytes());
			socket.shutdownOutput();

			String ret = read(reader,"utf-8");

			if(writer!=null) writer.close();
			if(reader!=null) reader.close();
			if(socket!=null) socket.close();

			if(ret.equals("error1"))
			{
				//密码错误，或者两次登陆的session不同
				response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=4");
			}
			else if(ret.equals("error2"))
			{
				//title += "您输入的用户名不存在，是否要注册这个帐户?\n";
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=6");
			}
			else if(ret.equals("error3"))
			{
				//title += "您输入的用户名和密码认证失败，是否需要找回密码？\n";
				response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=6");
			}
			else if(ret.equals("error4"))
			{
				 //严重错误，前台没有严格控制传入合法的用户名密码  
				response.sendRedirect("./pc.jsp?_user="+user+"&_pswd="+pswd+"&err=7");
			}
			else
			{

				String resultData = "<h2>验证成功</h2>";
				resultData += "<h4 class=\"desc\">帐号："+user_new+"</h4>";
				resultData += "<h4 class=\"desc\">密码："+pswd+"</h4>";
				resultData += "<a class=\"btn btn-danger btn\" style=\"margin-top:10px;\" href=\"./main.jsp?_user="+user_new+"&_pswd="+pswd+"&regnewFlag="+regnewFlag+"&game_fg="+game_fg+"\">进入游戏（简体）</a><br>";
				resultData += "<a class=\"btn btn-danger btn\" style=\"margin-top:10px;\" href=\"./main_ft.jsp?_user="+user_new+"&_pswd="+pswd+"&regnewFlag="+regnewFlag+"&game_fg="+game_fg+"\">進入遊戲（繁体）</a><br>";

				out.println(resultData);
			  // response.sendRedirect("./main.jsp?_user="+user_new+"&_pswd="+pswd+"&regnewFlag="+regnewFlag+"&game_fg="+game_fg);   
			}
		}
	}
}
%>
		</body>
		<script src="includes/jquery.min.js"></script>
		<script src="includes/bootstrap.min.js"></script>
		</html>
</body>
</html>
