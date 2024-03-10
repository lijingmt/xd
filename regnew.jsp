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
  <card id="entry" title="<%=gamename_cn%>"> <%
//if(request.getHeader("Via")==null)
//response.sendRedirect("./notMobile.jsp");
String m_key = request.getParameter("m_key");
String mid = request.getParameter("mid");
String from = request.getParameter("from");
if(mid==null){
	long ot = System.currentTimeMillis();
	mid=String.valueOf(ot);
}
if(m_key==null){
	long ot = System.currentTimeMillis();
	m_key=String.valueOf(ot);
}

	String error_str = request.getParameter("err");
	String p_user = request.getParameter("_user");
	String p_pswd = request.getParameter("_pswd");
if(p_user == null)
	p_user = "";
if(p_pswd == null)
	p_pswd = "";

	if("1".equals(error_str))
	out.print("友情提示：用户名和密码不能为空，请修改后重试。 <br/>");  
	else if("2".equals(error_str))
	out.print("友情提示：为了你的安全，用户名和密码不能少于2个字符，请修改后重试。 <br/>");
	else if("3".equals(error_str))
	out.print("友情提示：用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");  
	else if("4".equals(error_str))
	out.print("友情提示：该游戏帐号已经有人使用，请换一个账号重试。 <br/>");  
	else if("5".equals(error_str))
	out.print("友情提示：游戏账号和密码必须是2~11位的英文或者数字，或者两者的组合。 <br/>");  
	else if("6".equals(error_str))
	out.print("友情提示：您输入的用户名不存在，是否要注册这个帐户? <br/>");  
	%>
	<p>
	**仙道世界**<br/>
	<a href="./demo.jsp?_user=<%=mid%>&amp;_pswd=<%=m_key%>">+游客体验</a><br/>
	=新玩家注册=<br/>
	用户名和密码必须是2-11位之间，并且只能是数字和字母。<br/>
	注册帐号<br/>
	<input name="user" size="11" value="<%=p_user%>" maxlength="11" type="text" emptyok="false" format="*m"/><br/>
	设置密码<br/><input name="pswd" size="11"  value="<%=p_pswd%>" maxlength="11" type="text" emptyok="false" format="*m" /><br/>
	<anchor>注册
	<go href="./login_reg.jsp?regnewFlag=1&amp;<%=paraStringESC%>" method="post">
	<postfield name="_user" value="$(user)" />
	<postfield name="_pswd" value="$(pswd)" />
	</go>
	</anchor><br/>
	<%
	if(from == null || from == ""){
		out.print("<a href=\"./index.jsp?"+paraStringESC+"\">返回</a><br/>");
		out.print("<a href=\"./regneed.jsp?"+paraStringESC+"\">注册协议</a><br/>");
	}
	else{
		out.print("<a href=\"./xiand_intro.jsp?"+paraStringESC+"\">返回</a><br/>");
		out.print("<a href=\"./regneed.jsp?"+paraStringESC+"\">注册协议</a><br/>");
	}
	%>
----------<br/><%@include file="push.inc"%>                                                         
	<%--@include file="/comm/tail.inc"--%>
	</p>

	</card>
	</wml>
