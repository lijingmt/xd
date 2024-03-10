<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%> 
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

if( user==null || pswd==null)
{
	//out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
	response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=1&"+paraString);
}
else
{
	user = user.trim();
	pswd = pswd.trim();

	if(user.length() == 0 || pswd.length() == 0)
	{
		//	out.print("|"+user + "|:|" + pswd + "|<br/>");
		//	out.print("用户名和密码不能为空，请修改后重试。 <br/>");	
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=1&"+paraString);
	}
	else if( user.length()<2 || pswd.length()<2 )
	{
		//out.print("|"+user + "|:|" + pswd + "|<br/>");
		//out.print("为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");	
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=2&"+paraString);
	}
	else if( user.length()>11 || pswd.length()>11 )
	{
		//resultData += "游戏账号和密码必须是2~11位的英文或者数字，或者两者的组合<br/>";
		response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=5&"+paraString);
	}
	else
	{	
		String user_pswd = user + pswd;

		if(!isLegalChar(user_pswd))
		{
			//		out.print("|"+user + "|:|" + pswd + "|<br/>");
			//		out.print("用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");	
			response.sendRedirect("./regnew.jsp?_user="+user_url+"&_pswd="+pswd_url+"&err=3&"+paraString);
		}
		else 
		{
			Socket socket = new Socket(ip,port);
			InputStream reader = socket.getInputStream();
			OutputStream writer = socket.getOutputStream();

			String sid = (String)session.getId();

//			send(writer,("login_regnew "+projname+" "+user+" "+pswd+" "+sid+" "+game_pre).getBytes());
			send(writer,("login_regnew "+projname+" "+user+" "+pswd+" "+sid+" "+game_pre+" "+m_key+" "+userip+" "+userua).getBytes());
			send(writer,"flush_filter".getBytes());
			socket.shutdownOutput();

			String ret = read(reader,"utf-8");

			if(writer!=null) writer.close();
			if(reader!=null) reader.close();
			if(socket!=null) socket.close();

			if(ret.equals("error1"))
			{
				//resultData += "游戏帐号已经有人使用！<br/>";
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=4&"+paraString);
			}
			else if(ret.equals("error2"))
			{
				//resultData += "游戏账号和密码必须是2~11位的英文或者数字，或者两者的组合<br/>";
				response.sendRedirect("./regnew.jsp?_user="+user+"&_pswd="+pswd+"&err=5&"+paraString);
			}
			else
			{
				String resultData = "+游戏帐户注册成功！<br/>";
				resultData += "欢迎您进入《仙道》！<br/>";
				String stru="";
				String strp="";

				int i=0;
				for(i=0;i<ret.length()&&ret.charAt(i)!='|';i++)
					;
				if(i!=ret.length())
				{
					stru = ret.substring(0,i);
					strp = ret.substring(i+1,ret.length());
				}
				//	if(m_key != null)
				//	logger2.info("[uid:"+stru+"] [m_key:" + m_key + "]"); 
				loggerSpread.info("[m_key:"+m_key + "] [mid:"+mid + "] ["+game_pre+"] [uid:"+stru+ "] [spread_succ] [ap_info:"+ap_info+"]");  
				//log_spread_info(m_key,mid,"xd5",stru,ap_info);                                    
				resultData += "您的游戏账号是：<br/>"+stru+"<br/>";
				resultData += "您的游戏密码是：<br/>"+strp+"<br/>";
				resultData += "以上是您的游戏注册信息，请您牢记。<br/>";
				resultData += "----------<br/>";
				resultData += "您现在可以:<br/>";
				out.println(resultData);
				//if(from == null || from == "")
					out.print("<a href=\"./main.jsp?_user="+game_pre+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1&amp;game_fg="+game_pre+"\">立即进入游戏</a><br/>");
				//else
				//	out.print("<a href=\"./monst.jsp?from="+from+"&amp;_user="+user+"&amp;_pswd="+pswd+"&amp;_sid="+sid+"&amp;_mkey="+m_key+"&amp;_reg=1\">立即进入游戏</a><br/>");
			}
		}
	}
}
%>
</p>
</card>
</wml>
