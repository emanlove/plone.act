#!/usr/bin/make
#
pybot_options =

.PHONY: instance cleanall test robot robotsuite stop cached-eggs

BUILDOUT_COMMAND = ./bin/buildout -Nt 5
BUILDOUT_FILES = buildout.cfg pybot.cfg robotsuite.cfg setup.py bin/buildout

all: instance

ifneq ($(strip $(TRAVIS)),)
IS_TRAVIS = yes
endif

ifdef IS_TRAVIS

buildout-cache:
	mkdir $@

buildout-cache/downloads: buildout-cache
	mkdir $@

buildout-cache/eggs: buildout-cache
	mkdir $@

# use specific buildout that depends on cache
buildout.cfg: travis.cfg
	cp travis.cfg buildout.cfg

# use python as Travis has setup the virtualenv
bin/buildout: bootstrap.py buildout.cfg
	python bootstrap.py
	touch $@

cached-eggs: bin/buildout buildout-cache/downloads buildout-cache/eggs
	bin/buildout install download
	bin/buildout install install

else

# make a virtualenv
bin/python:
	virtualenv-2.7 --no-site-packages .
	touch $@

buildout.cfg: dev.cfg
	cp dev.cfg buildout.cfg


bin/buildout: bin/python bootstrap.py buildout.cfg
	./bin/python bootstrap.py
	touch $@

endif

bin/test: $(BUILDOUT_FILES)
	$(BUILDOUT_COMMAND) install test
	touch $@

parts/instance: $(BUILDOUT_FILES)
	$(BUILDOUT_COMMAND) install instance
	touch $@

bin/instance: parts/instance
	if [ -f var/plonesite ]; then rm var/plonesite; fi
	touch $@

var/plonesite:  bin/instance
	$(BUILDOUT_COMMAND) install plonesite
	touch $@

instance: var/plonesite
	bin/instance fg

cleanall:
	if [ -f var/supervisord.pid ]; then bin/supervisorctl shutdown; sleep 5; fi
	rm -fr bin develop-eggs downloads eggs parts .installed.cfg

test: bin/test
	./bin/test

bin/pybot: $(BUILDOUT_FILES)
	$(BUILDOUT_COMMAND) install robot
	touch $@

bin/zope-testrunner: $(BUILDOUT_FILES)
	$(BUILDOUT_COMMAND) -c robotsuite.cfg
	touch $@

bin/supervisord: $(BUILDOUT_FILES)
	$(BUILDOUT_COMMAND) install varnish-build varnish-conf varnish supervisor
	touch $@

bin/supervisorctl: bin/supervisord
	touch $@

var/supervisord.pid: bin/supervisord bin/supervisorctl
	if [ -f var/supervisord.pid ]; then bin/supervisorctl shutdown; sleep 5; fi
	bin/supervisord --pidfile=$@

robot: bin/pybot var/supervisord.pid
	bin/pybot $(pybot_options) -d robot-output acceptance-tests

robotsuite: bin/zope-testrunner
	mkdir -p robotsuite-output
	cd robotsuite-output && ../bin/zope-testrunner --path=../

stop:
	bin/supervisorctl shutdown
