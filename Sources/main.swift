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
                    poll["votes1"] = document["doc"]["votes1"].stringValue
                    poll["votes2"] = document["doc"]["votes2"].stringValue
                }
            }


        }
    }
}

    router.post("/polls/create") {
        request, response, next in
        defer{
            next()
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
