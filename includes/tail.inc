    <a href="http://tx.com.cn?z=<%=z%>">天下首页|</a><a href="http://tx.com.cn/?type=2&amp;z=<%=z%>">导航</a><br/>
    tx.com.cn<br/><%
    java.text.SimpleDateFormat formatternow = new java.text.SimpleDateFormat("HH:mm");
    java.util.Date currentTime_now = new java.util.Date();
    String dateStringnow = formatternow.format(currentTime_now);
    out.print(dateStringnow);%>
