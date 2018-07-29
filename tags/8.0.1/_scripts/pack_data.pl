# Script by grdn, 2012
# Used to pack the Data.lua automatically
# And yes, this is valid Perl code, kk? ;)

use strict;
my$d=q~C:\World of Warcraft\Interface\Addons\PokemonTrainer\Data.lua~;
my$s=qq|C:§World of Warcraft§WTF§Account§$ARGV[0]§SavedVariables§PokemonTrainer.lua|;
my$ptr=$ARGV[1]==1?1:0;if($ptr){
	$d=q#D:\Spiele\World of Warcraft Public Test\Interface\Addons\PokemonTrainer\Data_ptr.lua#;
	$s=qq|D:§Spiele§World of Warcraft Public test§WTF§Account§$ARGV[0]§SavedVariables§PokemonTrainer.lua|;
}
if(!$ARGV[0]){exit}
open(S,q^<^.join(q&\\&,split(q%§%,$s)))or die qq|Src not found!|;my@sr=<S>;close(S);
chomp@sr;my@re;my$db;for(@sr){if(m|^PTDevDB.=.{$|){$db=1;next}next if!$db;last if m|^}$|;
s|\s+(.+)$|$1|gi;s|(.+).--.*$|$1|gi;s|\[(\d+)\].=.(\d+)(,?)$|\[$1\]=$2$3|gi;
s|\[("?)(\w+)("?)\].=.{$|[$1$2$3]={|gi;push@re,$_;}do{my@ro;my$re=q##;for(@re){
if(length($re)>80&&length($_)>4){push@ro,$re;$re=q**;}$re.=$_;}$re=join(qq|\n|,@ro);
open(D,qq|>|.$d)or die qq|Dest not found!|;print D qq|local AddonName, PT = ...;\nlocal data = {\n|;
my$br=[];for(split//,$re){$$br[0]++if$_ eq qq!{!;$$br[1]++if$_ eq qq?}?;}print D qq|$re|;
print D q|}|x($$br[0]-$$br[1]);print D qq|\n};|;
print D qq`\nPT.Data={};\nsetmetatable(PT.Data,{__index=data,__newindex=function()end});`;close(D);}