string links;
string inventory_links;
string query_links(void|int count){
	if(links){
		return replace(links,"%d",""+count);
	}
	return "";
}
string query_inventory_links(void|int count){
	if(inventory_links){
		return replace(inventory_links,"%d",""+count);
	}
	return "";
}
