import sys, daemon, time



class testdaemon(daemon.Daemon):

    def run(self):
        a = ['a'] * (2**27 * int(sys.argv[2]))
        while True:
            time.sleep(1)

    def quit(self):
        pass

daemon = testdaemon()

if 'start' == sys.argv[1]: 
    daemon.start()

elif 'stop' == sys.argv[1]: 

    daemon.stop()

elif 'restart' == sys.argv[1]: 

    daemon.restart()
