/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#include <stdlib.h>

#include "mathlink.h"
#include "WolframLibrary.h"
#include "git2.h"
#include "Signature.h"
#include "GitLinkRepository.h"
#include "GitLinkCommit.h"

#include "Message.h"
#include "MLHelper.h"
#include "RepoInterface.h"


Signature::Signature()
{
	const char* name = NULL;
	const char* email = NULL;
	git_config* config;
	git_buf buf = GIT_BUF_INIT_CONST(NULL, 0);

	if (git_config_open_default(&config))
		return;

	if (!git_config_get_string_buf(&buf, config, "user.name"))
	{
		name = strdup(buf.ptr);
		git_buf_free(&buf);
		buf = GIT_BUF_INIT_CONST(NULL, 0);
	}
	if (!git_config_get_string_buf(&buf, config, "user.email"))
	{
		email = strdup(buf.ptr);
		git_buf_free(&buf);
	}

	if (name && email)
		git_signature_now(&sig_, name, email);
	if (name)
		free((void*)name);
	if (email)
		free((void*)email);
	git_config_free(config);
}

Signature::Signature(const Signature& signature)
{
	git_signature_dup(&sig_, signature.sig_);
}

Signature::Signature(const GitLinkRepository& repo)
{
	git_signature_default(&sig_, const_cast<git_repository*>(repo.repo()));
	if (sig_ == NULL)
		*this = Signature();
}

Signature::Signature(const GitLinkRepository& repo, const MLExpr& expr)
{
	if (expr.testSymbol("Automatic") || expr.testSymbol("None") || (expr.isList() && expr.length() == 0))
		*this = Signature(repo);
	else
		*this = Signature(expr);
}

Signature::Signature(const MLExpr& expr)
{
	MLExpr e = expr;

	if (e.isList())
	{
		if (e.length() == 0)
		{
			*this = Signature();
			return;
		}
		else if (expr.length() == 1)
			e = e.part(1);
		else if (expr.length() >= 2)
		{
			GitLinkRepository repo(expr.part(1));
			GitLinkCommit commit(repo, expr.part(2));
			const git_commit* c = commit.commit();
			const git_signature* s;

			if (c == NULL)
				return;
			if (expr.length() >= 3 && expr.part(3).testString("Author"))
				s = git_commit_author(c);
			else
				s = git_commit_committer(c);
			git_signature_dup(&sig_, s);
			return;
		}
	}
	if (e.testHead("Association"))
	{
		MLExpr nameExpr;
		MLExpr emailExpr;
		MLExpr timeExpr;

		for (int i = 1; i <= e.length(); i++)
		{
			if (!e.part(i).isRule())
				continue;
			MLExpr key = e.part(i).part(1);
			MLExpr value = e.part(i).part(2);
			if (key.testString("Name"))
				nameExpr = value;
			else if (key.testString("Email"))
				emailExpr = value;
			else if (key.testString("TimeStamp"))
				timeExpr = value;
		}

		const char* name = nameExpr.asString();
		const char* email = emailExpr.asString();
		time_t timeStamp = 0;
		int offset = 0;
		if (timeExpr.testHead("DateObject") && timeExpr.length() == 3 &&
			timeExpr.part(1).isList() && timeExpr.part(2).testHead("TimeObject") &&
			timeExpr.part(3).isRule() && timeExpr.part(3).part(1).testSymbol("TimeZone"))
		{
			double timeZone = timeExpr.part(3).part(2).asDouble();
			offset = 60 * timeZone;

			struct tm local_tm;
			local_tm.tm_sec = timeExpr.part(2).part(1).part(3).asInt();
			local_tm.tm_min = timeExpr.part(2).part(1).part(2).asInt();
			local_tm.tm_hour = timeExpr.part(2).part(1).part(1).asInt();
			local_tm.tm_mday = timeExpr.part(1).part(3).asInt();
			local_tm.tm_mon = timeExpr.part(1).part(2).asInt() - 1;
			local_tm.tm_year = timeExpr.part(1).part(1).asInt() - 1900;
			// I really don't know if setting tm_isdst to -1 is the best thing
			// to do here, but it produces the most correct results in my tests.
			// If we ever adopt Boost, should investigate redoing the time stuff.
			local_tm.tm_isdst = -1;
			timeStamp = mktime(&local_tm);
		}
		if (timeStamp && name && email)
			git_signature_new(&sig_, name, email, timeStamp, offset);
	}
	else if (e.isInteger())
		*this = Signature(GitLinkRepository(e));
	if (sig_ == NULL)
		*this = Signature();
}

Signature::Signature(const git_signature* signature)
{
	git_signature_dup(&sig_, signature);
}

Signature& Signature::operator=(const Signature& signature)
{
	if (sig_)
		git_signature_free(sig_);
	sig_ = NULL;
	if (signature.sig_)
		git_signature_dup(&sig_, signature.sig_);
	return *this;
}

void Signature::writeAssociation(MLINK lnk) const
{
	MLHelper helper(lnk);
	writeAssociation(helper);
}

void Signature::writeAssociation(MLHelper& helper) const
{
	if (sig_)
	{
		helper.beginFunction("Association");
		helper.putRule("Name", sig_->name);
		helper.putRule("Email", sig_->email);
		helper.putRule("TimeStamp", sig_->when);
		helper.endFunction();
	}
	else
		helper.putSymbol("$Failed");
}
