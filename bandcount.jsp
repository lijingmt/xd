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
	String p_regmobile = request.getParameter("_regmobile");
	String p_bandpswd = request.getParameter("_bandpswd");
if(p_user == null)
	p_user = "";
if(p_regmobile == null)
	p_regmobile = "";
if(p_bandpswd == null)
	p_bandpswd = "";

	else if("1".equals(error_str))
	out.print("友情提示：您输入的信息不能为空，请修改后重试。 <br/>");
	else if("2".equals(error_str))
	out.print("友情提示：您输入的信息不能少于2个字符，请修改后重试。 <br/>");
	else if("3".equals(error_str))
	out.print("友情提示：用户名和密码只能是大小写字母或数字，请修改后重试。 <br/>");  
	else if("4".equals(error_str))
	out.print("友情提示：您所填写的手机号码与您所绑定的手机号码不一致，请修改后再试。 <br/>");  
	else if("5".equals(error_str))
	out.print("友情提示：您所填写的安全码与您所设定的安全码不一致，请修改后再试。 <br/>");  
	else if("6".equals(error_str))
	out.print("友情提示：您输入的用户名不存在，请修改后再试。<br/>");  
	%>
	<p>
	**仙道世界**<br/>
	=冻结账号=<br/>
	请输入您要冻结的帐号<br/>
	<input name="user" size="11" value="<%=p_user%>" maxlength="11" type="text" emptyok="false" format="*m"/><br/>
	请输入您的绑定手机号码<br/>
	<input name="mobile" size="11"  value="<%=p_regmobile%>" maxlength="11" type="text" emptyok="false" format="*m" /><br/>
	请输入您的安全码<br/>
	<input name="pswd" size="11"  value="<%=p_bandpswd%>" maxlength="11" type="text" emptyok="false" format="*m" /><br/>
	<anchor>确定
	<go href="./bandcountpost.jsp?game_fg=xd&amp;<%=paraStringESC%>" method="post">
	<postfield name="_user" value="$(user)" />
	<postfield name="_regmobile" value="$(mobile)" />
	<postfield name="_bandpswd" value="$(pswd)" />
	</go>
	</anchor><br/>
	<a href="./bandcount.jsp">重新填写</a><br/>
	<%
	if(from == null || from == ""){
		out.print("<a href=\"./index.jsp?"+paraStringESC+"\">返回</a><br/>");
	}
	else{
		out.print("<a href=\"./xiand_intro.jsp?"+paraStringESC+"\">返回</a><br/>");
	}
	%>
----------<br/><%@include file="push.inc"%>                                                         
	<%--@include file="/comm/tail.inc"--%>
	</p>
	</card>
	</wml>
