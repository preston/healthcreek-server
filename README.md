# HealthCreek Server

HealthCreek Server is an API reference prototype for designing context-driven, patient-centered clinical experiences involving collaboration of multiple heterogeneous parties. It is an amalgamation of relevant existing standards and terminologies, fronted via a clean, RESTful JSON API that is easy to integrate into any JavaScript-based frontend, though *any* modern client is supported. The underlying internal domain model is represented as a normalized relational (PostgeSQL) schema.

# Conceptual Overview

The system allows for initial web-based login via a configurable set OpenID Connect providers: part of the OAuth2 family of protocols. After, both a browser-based sessions is established, as well as a JWT that may be used to access the API for a time-limited period. As this is a model-driven system, the documentation is generated based on the model. For what the API actually does, see:

* [High-Level List of REST Routes](https://github.com/preston/healthcreek-server/blob/master/doc/routes.txt) - This is a generated dump.
* [Interactive API Tutorial](https://github.com/preston/healthcreek-server/blob/master/doc/HealthCreek.paw). *Note*: You'll need [Paw](https://luckymarmot.com/paw) for OS X to open this, and need to replace the JWT and server instance configuration with your own details to run it.
* [Schema Diagram](https://github.com/preston/healthcreek-server/blob/master/doc/models_complete.svg) - This is a normalized .svg showing the physical database model, with additional OR/M-level annotations. It's useful in understanding how resources relate behind the API.
* [Database DSL](https://github.com/preston/healthcreek-server/blob/master/db/schema.rb) - Generated database schema in ActiveRecord format.

**The API is not a source of clinical knowledge.** All references are retained via URI types that are declared using external ontologies and stored elsewhere is appropriate authoritative systems. In other words, the server design is not intended to be used in isolated. It in only useful in the context of an available body knowledge with pre-agreed-upon terminology standards.

# Public Sandbox

A public sandbox server is available at:

	https://server.healthcreek.org

You may log in using any Google account. No authorization checks are performed in this environment; you have unrestricted access to the system, which is periodically reset. Synthetic seed data are pre-populated and fully CRUD'able for your convenience.

# The API 

## Pre-existing Security Resources

These endpoints would be pre-populated with "real" user data in an implementation prior to any actual use case. Most REST verbs are supported, used in the standard path'ing practice of "/<plural_noun>", "/<plural_noun>/:id", and utilization of sub-resources to represent model compositions and aggregations, when appropriate.

	/people # Generic type for all known people.
	/people/:id/identities # Actual authentication-related details specific to the IAM system.
	/people/:id/roles # Roles granted to the Person.
	/groups	# An aggregation of Persons.
	/groups/:id/members # Establishes a given Person's membership in a Group.
	/groups/:id/roles # Roles granted to the Group; transitively to all Members.
	/roles # Defines a granular set of permissions.

## Using the API to Model a Simple, Context-Driven Encounter

Consider the following scenario. Field-level details have been omitted for brevity.

### “Ernest Endocrinologist, MD” logs in either via OpenID Connect or JWT.

	POST /sessions # A secure cookie Session is issued.

### Ernest search for and selects “Peter Patient”.

	GET /people?role=patient&name=peter # returns a set of potential matches.
	GET /people/:id # get the specific patient
	External: GET problem list via patient URI.

### The UI automatically creates top-level "activity" context and participants. 

	GET /places?text=t # optionally find a place for the activity by searching for an existing one.
	POST /activities # issues a UUID (see the tutorial for fields)
	POST /activities/:id/actor_roles # add's Ernest as a physician participant
	POST /activities/:id/actor_roles # add's Peter as a patient participant
	POST /activities # we may also need to establish related activities referencing the former

### Ernest selects a problem such as “Diabetes Type II" as the focus of the activity.

	POST /activities/:id/usage_roles # add's Peter problem(s) as a referenced asset
	POST /activities/:id/objectives # declared the intended goal of the activity
	GET /activities/:id # reload the activity to see the re-built state and re-built state.

Now that the system has established sufficient participant and problem context, as is already aware of concept classes of highest relevance to the known participants via group/role memberships, the server is able able to provide the client with relevancy and/or time-sorted facts about the situation that are most relevant to Ernest’s interests in the problem, such as labs, meds, and whatever else is built into an underlying classifier or reasoner.

In HATEOAS style, the server is also able to provide *actionable* items to the client needed to emphasize the most likely client state transitions before, during and after the encounter.


# Developer Quick Start (OSX with Homebrew)

If you don't already have Postgres running locally:

    brew install postgresql

Create a "healthcreek" Postgres person using the dev/test credentials in config/database.yml, and assigned them full rights to manage schemas. As with most Ruby projects, use [RVM](https://rvm.io) to manage your local Ruby versions. [Install RVM](https://rvm.io) and:

	rvm install 2.3.1
	rvm use 2.3.1

Then,

	bundle install # to install all server-side library dependencies.

The HealthCreek Server application is designed in [12factor](http://12factor.net) style. Thus, the following environment variables are required to be set to support cookie-based CDN authorization grants. Set these in your ~/.bash_profile (or similar) and reload your terminal.

 * export HEALTHCREEK\_SECRET\_KEY\_BASE="some_unique_string" # Used for cryptographic signing.
 * export HEALTHCREEK\_DATABASE\_URL="postgres://healthcreek:password@db.example.com:5432/healthcreek_production
" # Only used in "production" mode!
 * export HEALTHCREEK\_DATABASE\_URL\_TEST="postgres://healthcreek:password@db.example.com:5432/healthcreek_test
" # Only used in "test" mode!


The following additional environment variables are optional, but potentially useful in a production context. Note that the database connection pool is adjusted automatically based on these values. If in doubt, do NOT set these.

 * export HEALTHCREEK\_SERVER\_PROCESSES=8 # To override the number of pre-forked workers.
 * export HEALTHCREEK\_SERVER\_THREAD=8 # To override the number of threads per process.

Now,

	rake db:create # to create empty healthcreek_development and healthcreek_test databases in Postgres
	rake db:migrate # to apply all database migrations, in order, transactionally
	rake db:seed # loads a simple set of starter data
	rake test # to run all regression tests and generate a code coverage report. everything should pass!

You're now ready to run the application.

	rails s # to run the server in development mode in the foreground.

To automatically re-run regression tests on detected code changes, open another terminal window and run

	guard # hit <enter> to manually re-run all tests to run if a change isn't detected

# Deployment

Deployment is done exclusively with Docker, though "raw" deployment using Passenger and all another common methods, including Heroku, are supported as well.

## Building a Container

To build your current version:

	docker build -t p3000/healthcreek-server:latest .

## Running a Container

When running the container, **all environment variables defined in the above section must be set using `-e FOO="bar"` options** to docker. The foreground form of the command is:

	docker run -it --rm -m="512MB" \
		-e "HEALTHCREEK_SECRET_KEY_BASE=development_only" \
		-e "HEALTHCREEK_DEVELOPMENT_URL=postgresql://healthcreek:password@192.168.1.103:5432/healthcreek_development" \
		-e "HEALTHCREEK_DEVELOPMENT_URL_TEST=postgresql://healthcreek:password@192.168.1.103:5432/healthcreek_test" \
		healtcreek-server:latest

...or to run in the background:

	docker run -d --rm -p 3000:3000 -m="512MB" \
		-e "HEALTHCREEK_SECRET_KEY_BASE=development_only" \
		-e "HEALTHCREEK_DEVELOPMENT_URL=postgresql://healthcreek:password@192.168.1.103:5432/healthcreek_development" \
		-e "HEALTHCREEK_DEVELOPMENT_URL_TST=postgresql://healthcreek:password@192.168.1.103:5432/healthcreek_test" \
		healtcreek-server:latest

## Regression Testing a Container

The container includes a regression test suite to ensure proper operation. Running in test mode is slightly different, as to not inadvertently affect your production database(s). The application server process must also be told to run in 'test' mode.

docker run -it -m="512MB" \
	-e "RAILS_ENV=test" \
	-e "HEALTHCREEK_ENV_VAR_NAME=value" \
	... \
	healtcreek-server:latest \
	rake test


# Attribution

Blame this on Preston Lee <preston@asu.edu>. "You're welcome" or "I'm sorry": whichever best applies.
