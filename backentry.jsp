<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN" "http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<%@include file="includes/header.inc"%>
<%String gamename_cn_utf8 = new String(gamename_cn.getBytes("ISO8859-1"),"gb2312");%>
<wml>
  <head>
    <meta http-equiv="Cache-Control" content="max-age=0"/>
    <meta http-equiv="Cache-Control" content="no-cache" />
  </head>
  <card id="entry">
  <p><%=gamename_cn%>后台</p>
  <p>账号:<input name="user" size="12" maxlength="12" type="text" emptyok="false" /><br/>
	密码:<input name="pswd" size="12" maxlength="12" type="text" emptyok="false" /><br/>
	<anchor>进入游戏
	<go href="./manager.jsp?game_fg=<%=game_pre%>" method="post">
	<postfield name="_user" value="$(user)" />
	<postfield name="_pswd" value="$(pswd)" />
	</go>
	</anchor><br/>
	<a href="./bandcount.jsp">冻结帐号</a><br/>
	<a href="./regnew.jsp?<%=paraStringESC%>">新玩家注册</a><br/>
	</p>
	</card>
	</wml>
