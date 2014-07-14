(* ::Package:: *)

(* ::Input:: *)
(*Quit*)


(* ::Subsection::Closed:: *)
(*Init*)


InitializeGitLibrary[] := 
Block[{path},
	path = FindLibrary["gitlink"];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;

		GL`libGitVersion = LibraryFunctionLoad[$GitLibrary, "libGitVersion", {}, {Integer, 1}];
		GL`libGitFeatures = LibraryFunctionLoad[$GitLibrary, "libGitFeatures", LinkObject, LinkObject];

		GL`GitRepoQ = LibraryFunctionLoad[$GitLibrary, "GitRepoQ", {"UTF8String"}, "Boolean"];
		GL`GitRemoteQ = LibraryFunctionLoad[$GitLibrary, "GitRemoteQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitBranchQ = LibraryFunctionLoad[$GitLibrary, "GitBranchQ", {Integer, "UTF8String"}, "Boolean"];

		GL`GitProperties = LibraryFunctionLoad[$GitLibrary, "GitProperties", LinkObject, LinkObject];

		GL`GitFetch = LibraryFunctionLoad[$GitLibrary, "GitFetch", {Integer, "UTF8String", "Boolean"}, "UTF8String"];
		GL`GitPush = LibraryFunctionLoad[$GitLibrary, "GitPush", {Integer, "UTF8String", "UTF8String"}, "UTF8String"];

		GL`AssignToManagedRepoInstance = LibraryFunctionLoad[$GitLibrary, "assignToManagedRepoInstance", {"UTF8String", Integer}, "UTF8String"];
		"Initialization complete";
	]
]


assignToManagedRepoInstance[repo_String, GitRepo[id_Integer]] :=
	If[GL`AssignToManagedRepoInstance[repo, id] === "", $Failed, GitRepo[id]]


(* ::Subsubsection::Closed:: *)
(*Introspection*)


$GitLibraryInformation := 
Association[{
	"Version" -> Replace[GL`libGitVersion[], {a_List :> StringJoin[Riffle[ToString /@ a, "."]], _ -> None}],
	"Features" -> Replace[GL`libGitFeatures[], {a_List :> a, _ -> None}],
	"Location" -> Replace[$GitLibrary, {a_String :> a, _ -> Missing["NotFound"]}],
	"Date" -> Replace[$GitLibrary, {a_String :> FileDate[a], _ -> None}]
}]


(* ::Subsubsection::Closed:: *)
(*Q functions*)


GitRepoQ[repo_String] := GL`GitRepoQ[AbsoluteFileName[repo]];


GitRemoteQ[GitRepo[id_Integer], remote_String] := GL`GitRemoteQ[id, remote];


GitBranchQ[GitRepo[id_Integer], branch_String] := GL`GitBranchQ[id, branch];


(* ::Subsubsection::Closed:: *)
(*Query functions*)


GitProperties[GitRepo[id_Integer]] := GL`GitProperties[id];

GitProperties[repo: GitRepo[_Integer], All] := GitProperties[repo];
GitProperties[repo: GitRepo[_Integer], "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitProperties[repo], prop]


(* ::Subsubsection::Closed:: *)
(*Git commands*)


GitOpen[repo_String]:=
	With[{path = AbsoluteFileName[repo]},
		If[GitRepoQ[path],
			assignToManagedRepoInstance[path, CreateManagedLibraryExpression["gitRepo", GitRepo]],
			$Failed] ];	


errorValueQ[str_String] := (str =!= "success")


Options[GitFetch] = {"Prune" -> False};

GitFetch[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	With[{result = GL`GitFetch[id, remote, TrueQ @ OptionValue["Prune"]]},
		If[errorValueQ[result], Message[MessageName[GitFetch, result], id, remote]; $Failed, result] ]


Options[GitPush] = {};

GitPush[GitRepo[id_Integer], remote_String, branch_String, OptionsPattern[]] :=
	With[{result = GL`GitPush[id, remote, branch]},
		If[errorValueQ[result], Message[MessageName[GitPush, result], id, remote, branch]; $Failed, result] ]


(* ::Subsection:: *)
(*Tests*)


(* ::Input:: *)
(*AppendTo[$LibraryPath, "~/bin/"];*)
(*InitializeGitLibrary[]*)


(* ::Input:: *)
(*$GitLibraryInformation*)


(* ::Input:: *)
(*{GitRepoQ["/Users/jfultz/wolfram/fe/Fonts"],GitRepoQ["/Users/jfultz/wolfram/fe"],GitRepoQ["/files/git/fe/Fonts"]}*)


(* ::Input:: *)
(*repo=GitOpen["/Users/jfultz/test_repo"]*)


(* ::Input:: *)
(*GitProperties[repo]*)


(* ::Input:: *)
(*{GitRemoteQ[repo,"origin"],GitRemoteQ[repo,"foo"]}*)


(* ::Input:: *)
(*{GitBranchQ[repo,"master"],GitBranchQ[repo,"foo"]}*)


(* ::Input:: *)
(*repo2=GitOpen["/Users/jfultz/wolfram/git/Test2"]*)


(* ::Input:: *)
(*GitRemoteQ[repo2,"origin"]*)


(* ::Input:: *)
(*GitProperties[repo2]*)


(* ::Input:: *)
(*GitFetch[repo2,"origin"]*)


(* ::Input:: *)
(*repo = GitOpen["/files/git/fe/Fonts"]*)


(* ::Input:: *)
(*GitRemoteQ[repo, "origin"]*)


(* ::Input:: *)
(*GitFetch[repo, "origin"]*)


(* ::Subsection:: *)
(*WRI*)


WRIGitConfigured[repoObj_] := True (* more to come *)


pullRequestBranchCheck[repoObj_GitObject, branch_String, remote_String] :=
	GitBranchQ[repoObj, branch, remote] &&
		If[GitBranchQ[repoObj, branch],
			GitCommitParentQ[GitCommitObject[repoObj, branch], GitCommitObject[repoObj, branch, remote]], True];


readyToMergePullRequest[repoObj_GitObject, source_String, remote_String] :=
	Module[{},
		return=GitRemoteQ[repoObj, remote] && GitFetch[repoObj, remote, "Prune"->True];
		return=return&&pullRequestBranchCheck[repoObj, source, remote];
		return
	]


getWRIRepo[repo_String, remote_String] := Module[{repoObj},
	repoObj = GitOpen[repo];
	If[repoObj =!= $Failed && GitRemoteQ[repoObj, remote] && WRIGitConfigured[repoObj],
		repoObj,
		(*Quiet[GitClose[repoObj]];*) $Failed]];


rebasePullRequest[repoObj_GitObject, branch_String,remote_String, andSquash_]:=
	Module[{},
	]


MergePullRequest[repo_String, branch_String, opts_] :=
	Catch[Module[{repoObj, remote="Remote"/.opts/."Remote"->"origin", squash="Squash"/.opts/."Squash"->True},
		If[!GitRepoQ[repo], Message[MergePullRequest::repoNotFound]; Throw[$Failed]];
		If[!getWRIRepo[repo]===$Failed, Message[MergePullRequest::badRepo]; Throw[$Failed]];
		If[!readyToMergePullRequest[repoObj,branch,remote], Message[MergePullRequest::badBranch]; Throw[$Failed]];
		If[!rebasePullRequest[repoObj,branch,remote,squash], Message[MergePullRequest::cantRebase]; Throw[$Failed]];
		If[GitBranchQ[repoObj,branch],GitDeleteBranch[repoObj,branch]];
		GitCommitObject[repoObj,"master"]
	]]




repo