<%@include file="includes/pike.inc"%>
<%@include file="includes/config.inc"%>
<%
	String uid = request.getParameter("uid"); 
	String point = request.getParameter("point");
	String present = request.getParameter("present");

        if (present == null)present = "0";
	logger.debug("[uid:"+uid+"] [point:" + point + "] [present:"+present+"] [succ]");
	String pike_url = "/usr/local/games/"+gamename+"/callback_add.pike";
	String result = exec_pike(pike_url,uid,point,"xianyuanyu",present);

	if("0".equals(result))
		out.print("0");
	else
		out.print("200");
%>
