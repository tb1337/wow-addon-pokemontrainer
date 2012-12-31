use strict;my$d=q~C:\World of Warcraft\Interface\Addons\PokemonTrainer\Data.lua~;
my$s=qq°C:§World of Warcraft§WTF§Account§$ARGV[0]§SavedVariables§PokemonTrainer.lua°;
open(S,q^<^.join(q&\\&,split(q%§%,$s)))or die qq€Src not found!€;my@sr=<S>;close(S);
chomp@sr;my@re;my$db;for(@sr){if(m|^PTDevDB.=.{$|){$db=1;next}next if!$db;last if m|^}$|;
s|\s+(.+)$|$1|gi;s|(.+).--.*$|$1|gi;s|\[(\d+)\].=.(\d+)(,?)$|\[$1\]=$2$3|gi;
s|\[("?)(\w+)("?)\].=.{$|[$1$2$3]={|gi;push@re,$_;}do{my@ro;my$re=qññ;for(@re){
if(length($re)>80&&length($_)>4){push@ro,$re;$re=q**;}$re.=$_;}$re=join(qq÷\n÷,@ro);
open(D,qqµ>µ.$d)or die qq¦Dest not found!¦;print D q¬local AddonName, PT = ...;
local data = {
¬;print D qq¹$re¹;print D q³}};
PT.Data={};
setmetatable(PT.Data,{__index=data,__newindex=function()end});³;close(D);}