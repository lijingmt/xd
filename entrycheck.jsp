<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%> 
<%@ page import="com.lj.ip.*,java.net.*,java.util.*,java.io.*" %>
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
	String pswd = request.getParameter("_pswd");
	String regnewFlag = (String)request.getParameter("regnewFlag");  
	String game_fg = (String)request.getParameter("game_fg");  

	 String m_key = (String)session.getAttribute("m_key");   


if( user==null || pswd==null)
{
	//out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
	response.sendRedirect("./index.jsp?err=1");
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
		response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=1");
	}
	else if( user.length()<2 || pswd.length()<2 )
	{
		//out.print("|"+user + "|:|" + pswd + "|<br/>");
		//out.print("为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");	
		response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=2");
	}
	else if( user.length()>12 || pswd.length()>12 )
	{
		//resultData += "游戏账号和密码必须是2~12位的英文或者数字，或者两者的组合<br/>";
		response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=5");
	}
	else
	{	
		String user_pswd = user + pswd;

		if(!isLegalChar(user_pswd))
		{
			//out.print("|"+user + "|:|" + pswd + "|<br/>");
			//out.print("用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");	
			response.sendRedirect("./index.jsp?_user="+user_url+"&_pswd="+pswd_url+"&err=3");
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
				response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=4");
			}
			else if(ret.equals("error2"))
			{
				//title += "您输入的用户名不存在，是否要注册这个帐户?\n";
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=6");
			}
			else if(ret.equals("error3"))
			{
				//title += "您输入的用户名和密码认证失败，是否需要找回密码？\n";
				response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=6");
			}
			else if(ret.equals("error4"))
			{
				 //严重错误，前台没有严格控制传入合法的用户名密码  
				response.sendRedirect("./index.jsp?_user="+user+"&_pswd="+pswd+"&err=7");
			}
			else
			{
			   response.sendRedirect("./main.jsp?_user="+user_new+"&_pswd="+pswd+"&regnewFlag="+regnewFlag+"&game_fg="+game_fg);   
			}
		}
	}
}
%>
</p>
</card>
</wml>
