<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<wml>
  <head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-Control" content="no-cache" />
  </head>
<card id="regnewwrong">
    <p>
    **仙道世界**<br/>
    注册错误！<br/>
    两次输入密码不一致！<br/>
    注册游戏帐号<br/><input name="user" size="12" maxlength="12" type="text" emptyok="false" /><br/>
    请输入密码<br/><input name="pswd" size="12" maxlength="12" type="text" emptyok="false" /><br/>
    请再输入一次密码<br/><input name="pswd2" size="12" maxlength="12" type="text" emptyok="false" />
    </p>
    <p>
    <anchor>我同意协议并提交注册
    <go href="./redrect.jsp?regnewFlag=1" method="post">
      <postfield name="_user" value="$(user)" />
      <postfield name="_pswd" value="$(pswd)" />
      <postfield name="_pswd2" value="$(pswd2)" />
    </go>
    </anchor>
    </p>
    <p>
   	<a href="./index.jsp">不同意注册协议</a><br/>
    <a href="./regneed.jsp">+注册协议</a><br/>
 	--------<br/>
    <a href="./index.jsp">+仙道首页</a><br/>
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
