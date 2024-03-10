<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%> 
<%@include file="includes/pike.inc"%>
<%@ page import="com.lj.ip.*" %>
<wml>
  <head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-Control" content="no-cache" />
  </head>
  <card id="checkInput"> <p><%
  String z = (String)request.getParameter("z");

if(z==null)
	z=(String)request.getSession().getAttribute("z");
	else
	request.getSession().setAttribute("z",z);


	String user = request.getParameter("_user");
	String regmobile = request.getParameter("_regmobile");
	String bandpswd = request.getParameter("_bandpswd");
	String game_fg = request.getParameter("game_fg");
	
	String from= (String)request.getParameter("from");
	String ap_info= (String)request.getParameter("ap_info");

	String user_url = java.net.URLEncoder.encode(user,"UTF-8");
	String mobile_url = java.net.URLEncoder.encode(regmobile,"UTF-8");
	String pswd_url = java.net.URLEncoder.encode(bandpswd,"UTF-8");

if( user==null || regmobile==null || bandpswd==null)
{
	//out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
	response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=1&"+paraString);
}
else
{
	user = user.trim();
	regmobile = regmobile.trim();
	bandpswd = bandpswd.trim();

	if(user.length() == 0 || regmobile.length() == 0|| bandpswd.length() == 0)
	{
		//	out.print("|"+user + "|:|" + pswd + "|<br/>");
		//	out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
		response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=1&"+paraString);
	}
	else if( user.length()<2 || regmobile.length()<2 || bandpswd.length()<2)
	{
		//out.print("|"+user + "|:|" + pswd + "|<br/>");
		//out.print("为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");	
		response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=2&"+paraString);
	}
	else if( user.length()>11 || regmobile.length()>11 || bandpswd.length()>11)
	{
		response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=5&"+paraString);
		//resultData += "游戏账号和密码必须是2~11位的英文或者数字，或者两者的组合<br/>";
	}
	else
	{	
		String user_pswd = user + regmobile + bandpswd;

		if(!isLegalChar(user_pswd))
		{
			//		out.print("|"+user + "|:|" + pswd + "|<br/>");
			//		out.print("用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");	
			response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=3&"+paraString);
		}
		else 
		{
			Socket socket = new Socket(ip,port);
			InputStream reader = socket.getInputStream();
			OutputStream writer = socket.getOutputStream();

			send(writer,("login_band "+projname+" "+user+" "+regmobile+" "+bandpswd+" "+game_pre).getBytes());
			send(writer,"flush_filter".getBytes());
			socket.shutdownOutput();

			String ret = read(reader,"utf-8");

			if(writer!=null) writer.close();
			if(reader!=null) reader.close();
			if(socket!=null) socket.close();

			if(ret.equals("error2"))
				//resultData += "游戏账号和密码必须是2~11位的英文或者数字，或者两者的组合<br/>";
				response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=3&"+paraString);
			else if(ret.equals("error4"))
				response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=4&"+paraString);
			else if(ret.equals("error5"))
				response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=5&"+paraString);
			else if(ret.equals("error6"))
				response.sendRedirect("./bandcount.jsp?_user="+user+"&_regmobile="+regmobile+"&_bandpswd="+bandpswd+"&err=6&"+paraString);
			else if(ret.equals("bandok"))
			{
				//includes/pike.inc中实现调用pike来修改密码方法
				String pike_url = "/usr/local/games/"+gamename+"/change_pswd.pike";
				//long time = new java.util.Date().getTime();
				Long curDate=new java.util.Date().getTime();
				String time=curDate + "";
				time = time.substring(2,13);
				String user_new =game_fg+user;

				String result = exec_pike(pike_url,user_new,time);
				String result1 = exec_pike(pike_url,user_new,time);
				
				String resultData = "+您的帐号已经成功冻结！<br/>";
				resultData += "任何人不能利用此账号登陆游戏<br/>";
				resultData += "解除冻结请拨打游戏客服电话 (010)58621742<br/>";
				out.print(game_fg+"<br/>");
				out.print(resultData+"<br/>");
				out.print("<a href=\"./index.jsp\">返回</a><br/>");
			}
			else{
				String resultData = "服务器正在维护当中，请稍后再试<br/>";
				resultData += "如有问题请拨打游戏客服电话 (010)58621742<br/>";
				out.print(resultData+"<br/>");
				out.print("<a href=\"./index.jsp\">返回</a><br/>");
			}
		}
	}
}
%>
</p>
</card>
</wml>
