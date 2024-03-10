<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<wml>
<head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-control" content="no-cache" />
</head>
<card title="仙道" id="wronginput">
<p>
您的输入有误，用户名和密码不能为空，也不能为中文和特殊字符，请返回重试。 <br/>
 	--------<br/>
<a href="./index.jsp">仙道首页</a><br/>
成仙从魔一念间<br/>
<a href="http://wap.dogstart.com">dogstart.com</a><br/>
 	--------<br/>
<%
    	java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
        java.util.Date currentTime_now = new java.util.Date();
    	String dateStringnow = formatternow.format(currentTime_now);
        out.println(dateStringnow);
%>
</p>
</card> 
</wml>
