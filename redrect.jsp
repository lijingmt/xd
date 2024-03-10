<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%>
<wml>
  <head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-Control" content="no-cache" />
  </head>
  <card id="checkInput">
    <p>
<%
try
{
	String user = request.getParameter("_user");
	String pswd = request.getParameter("_pswd");
	String pswd2 = request.getParameter("_pswd2");
	String regnewFlag = (String)request.getParameter("regnewFlag");
	int rightFlag = 1;
	if( user==null || pswd==null || user.equals("") || pswd.equals("") || user.equals(" ") || pswd.equals(" "))
	{
		response.sendRedirect("./wronginput.jsp");
	}
	else if( user.length()<2 || pswd.length()<2 )
	{
		response.sendRedirect("./wronginput.jsp");
	}
	else
	{	//这里进行中文监测和特殊字符检测，另外，需要在system/cmd/login_check.pike中进行
		//监测，因为有人直接用url+参数来进行登陆，这一页是不会起作用的
		String rightChar = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
		//监测用户名
		for (int i = 0; i < user.length(); i++)
		{
			char c = user.charAt(i);//字符串中的字符
			if ( rightChar.indexOf(c) == -1 )
			{
				rightFlag = 0;
				break;
			}
		}
		//监测密码
		for (int i = 0; i < pswd.length(); i++)
		{
			char c = pswd.charAt(i);//字符串中的字符
			if ( rightChar.indexOf(c) == -1 )
			{
				rightFlag = 0;
				break;
			}
		}

	}
	////////////////////////////////////////////////////////////
	if(rightFlag == 0)
	{
		response.sendRedirect("./wronginput.jsp");
	}
 	else if(rightFlag == 1 && pswd.equals(pswd2) )	
	{
		response.sendRedirect("./main.jsp?_user="+user+"&_pswd="+pswd+
				"&regnewFlag="+regnewFlag+"&"+paraString);
	}
	else
		response.sendRedirect("./regnewwrong.jsp");
}
catch(Exception uae)
{
        System.out.println("[wrong input exception]"+uae+"\n");
}
%>
    </p>
  </card>
</wml>
