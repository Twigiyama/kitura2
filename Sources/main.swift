import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON
import CouchDB
import Foundation


HeliumLogger.use()

let connectionProperties = ConnectionProperties(host: "localhost", port: 5984, secured: false)
let client = CouchDBClient(connectionProperties: connectionProperties)
let database = client.database("polls")

let router = Router()




router.get("/polls/list") {
    request, response, next in

    database.retrieveAll(includeDocuments: true) {
        docs, error in

        defer {
            next()
        }

        if let error = error {

            let errorMessage = error.localizedDescription
            let status = ["status": "error", "message": errorMessage]
            let result = ["result": status]
            let json = JSON(result)

            response.status(.OK).send(json: json)

        } else {

            let status = ["status": "ok"]
            var polls = [[String: Any]]()
            if let docs = docs {
                for document in docs["rows"].arrayValue {
                    var poll = [String: Any]()
                    poll["id"] = document["id"].stringValue
                    poll["title"] = document["doc"]["title"].stringValue
                    poll["option1"] = document["doc"]["option1"].stringValue
                    poll["option2"] = document["doc"]["option2"].stringValue
                    poll["votes1"] = document["doc"]["votes1"].intValue
                    poll["votes2"] = document["doc"]["votes2"].intValue
                    polls.append(poll)
                    }
                }
            let result: [String: Any] = ["result": status, "polls": polls]
            let json = JSON(result)

            response.status(.OK).send(json: json)

            }
        }
}
    router.post("/polls/create", middleware: BodyParser())
    router.post("/polls/create") {
        request, response, next in
        defer{
            next()
        }
        // Check that the request body has something in it
        guard let values = request.body else {
            try response.status(.badRequest).end()
            return
        }

        // Check if request if body has urlEncoded values
        guard case .urlEncoded(let body) = values else {
            try response.status(.badRequest).end()
            return
        }

        let fields = ["title", "option1", "option2"]

        var poll = [String: Any]()
        for field in fields {
            if let value = body[field]?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if value.characters.count > 0 {
                    poll[field] = value
                    continue
                }
            }
            //  if there is no value, then send back bad request
            try response.status(.badRequest).end()
            return
        }
    }

    router.post("/polls/vote/:pollid/:option") {
        requst, response, next in
        defer{
            next()
        }
    }

    Kitura.addHTTPServer(onPort: 8090, with: router)
    Kitura.run()
