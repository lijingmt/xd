<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<% response.setContentType("text/vnd.wap.wml;charset=UTF-8");%>
<%@ page language="java" contentType="text/vnd.wap.wml;charset=UTF-8"%>
<wml>
<head>
<meta http-equiv="Cache-Control" content="max-age=0"/>
</head>
<card title="仙道">
	<p align="left">
	仙道2008年6月26日更新重启公告<br/>
	仙道游戏定于2008年6月26日下午2点进行服务器更新重启<br/>
	一.正式开放"技能书购买"功能<br/>
	1.30级以下技能书可以在从仙镇杂货铺(人类)及羽化村稻草小店(妖魔)里购买到<br/>
	2.玩家打怪仍有几率掉落技能书<br/>
	二.端午节活动正式关闭<br/>
	粽子将不会再掉落,粽子也将不能再投放,粽子商人也将消失<br/>
	三.四区，五区，六区合区信息<br/>
	仙道游戏定于下周一(即2008年6月30日)关闭四区,五区,六区进行合区操作,预计于下周四(即2008年7月3日)正式开放合区<br/>
	祝您游戏愉快!<br/>
	您的支持就是我们最大的动力!<br/>
	2008年6月26日<br/>
	--------<br/>
	<a href="http://wap.dogstart.com">dogstart.com</a><br/>
	--------<br/>
<%
java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
java.util.Date currentTime_now = new java.util.Date();
String dateStringnow = formatternow.format(currentTime_now);
out.print(dateStringnow);%>
</p>
</card>
</wml>
