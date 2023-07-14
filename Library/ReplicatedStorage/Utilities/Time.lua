-- Time: Offers the same interface as TestTime
return {
	defer = task.defer,
	delay = task.delay,
	spawn = task.spawn,
	wait = task.wait,

	clock = os.clock,
	time = os.time,

	Heartbeat = game:GetService("RunService").Heartbeat,
}