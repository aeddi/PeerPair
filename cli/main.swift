import Foundation
import Darwin

class MainTest {
    private let gameService = GameService()
    var log = ""

	init() {
		gameService.delegate = self
	}

	func connect() {
		gameService.startSearchingForPlayers()
	}

	func ping() {
        gameService.ping()
	}

	func disconnect() {
        gameService.disconnect()
	}

    func updateView() {
		let lines = log.components(separatedBy: "\n")
		for line in lines {
			let trimed = line.trimmingCharacters(in: .whitespaces)
			if !trimed.isEmpty {
				print("\u{001B}[2K\r", terminator: "")
				print("\tLog: \(trimed)")
			}
		}
	}

    lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm:ss.SSS"
        return formatter
    }()

    var timestampPrefix: String {
        return "\(currentTime): "
    }

    var currentTime: String {
        return formatter.string(from: Date())
    }
}

extension MainTest: GameServiceDelegate {
    func networkLog(_ logText: String) {
        log += "\(timestampPrefix)\(logText)\n"
		self.updateView()
    }
}

let test = MainTest()
print("Commands available: connect, ping, disconnect and exit\n")

DispatchQueue.global(qos: .background).async(execute: {
	while true {
		print("> ", terminator:"")
		let command = readLine(strippingNewline: true)!

		switch command {
		case "connect":
			test.connect()
		case "ping":
			test.ping()
		case "disconnect":
			test.disconnect()
		case "exit":
			exit(0)
		default:
			print("error: unknown command")
		}
	}
})

dispatchMain()
