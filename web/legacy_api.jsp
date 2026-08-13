<%@ page language="java" contentType="text/html;charset=UTF-8"
    import="java.io.*,java.net.*" %>
<%!
String readLegacyApi(InputStream input) throws IOException
{
    BufferedReader reader = new BufferedReader(
        new InputStreamReader(input,"UTF-8"));
    StringBuilder result = new StringBuilder();
    char[] buffer = new char[8192];
    int count;
    while((count=reader.read(buffer))!=-1)
        result.append(buffer,0,count);
    return result.toString();
}
%>
<%
request.setCharacterEncoding("UTF-8");
response.setHeader("Cache-Control","no-store, no-cache, must-revalidate");
response.setHeader("Pragma","no-cache");
String query = request.getQueryString();
if(query==null || query.length()>65536){
    response.sendError(400,"Invalid legacy request");
    return;
}
HttpURLConnection connection = null;
try{
    URL endpoint = new URL("http://127.0.0.1:8888/api/html?"+query);
    connection = (HttpURLConnection)endpoint.openConnection();
    connection.setConnectTimeout(5000);
    connection.setReadTimeout(35000);
    connection.setUseCaches(false);
    connection.setRequestMethod("GET");
    int status = connection.getResponseCode();
    InputStream input = status>=400 ? connection.getErrorStream() :
        connection.getInputStream();
    String html = input==null ? "" : readLegacyApi(input);
    String compatibilityPath = request.getContextPath()+"/legacy_api.jsp";
    html = html.replace("/api/html",compatibilityPath);
    response.setStatus(status);
    response.getWriter().write(html);
}
catch(Exception error){
    response.sendError(503,"游戏入口暂时繁忙，请稍后重试");
}
finally{
    if(connection!=null)
        connection.disconnect();
}
%>
