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

extension String {
    func removingHTMLEncoding() -> String {
        let result = self.replacingOccurrences(of: "+", with: " ")
        return result.removingPercentEncoding ?? result
    }
}


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
                    poll[field] = value.removingHTMLEncoding()
                    continue
                }
            }
            //  if there is no value, then send back bad request
            try response.status(.badRequest).end()
            return
        }

        // fill in default values for the vote counts
        poll["votes1"] = 0
        poll["votes2"] = 0

        // convert it to JSON which is what CouchDB ingests

        let json = JSON(poll)

        database.create(json) {id, revision, doc, error in
            defer { next() }

            if let id = id {
                //means id is not null so document was successfully created
                let status = ["status": "ok", "id": id]
                let result = ["result": status]
                let json = JSON(result)

                response.status(.OK).send(json: json)
            } else {
                //something has gone catastrophically wrong
                let errorMessage = error?.localizedDescription ?? "Unknown error"
                let status = ["status": "error", "message": errorMessage]
                let result = ["result": status]
                let json = JSON(result)
                response.status(.internalServerError).send(json: json)
            }

        }
    }

    router.post("polls/delete/:pollid") {
        request, response, next in
        defer{
            next()
        }

        //ensure the parameter has a value

        guard let poll = request.parameters["pollid"] else
        {
            try response.status(.badRequest).end()
            return
        }

        //we need the rev of the document to delete it
        database.retrieve(poll) {doc, error in

            if let error = error {
                // something went wrong
                let errorMessage = error.localizedDescription
                let status = ["status": "error3", "message": errorMessage]
                let result = ["result": status]
                let json = JSON(result)

                response.status(.notFound).send(json:json)
                next()
            } else if let doc = doc {

                //get the id and the rev of the document to delete
                let id = doc["id"].stringValue
                let rev = doc["_rev"].stringValue

                //attempt to delete the document
                database.delete(id, rev: rev) { error in

                    if let error = error {

                        let errorMessage = error.localizedDescription
                        let status = ["status": "error", "message": errorMessage]
                        let result = ["result": status]
                        let json = JSON(json)

                        //can't delete for some reason.  Not sure what status response to put really.
                        response.status(.internalServerError).send(json:json)


                        next()
                    } else {
                        let status = ["status": "OK"]
                        let result = ["result": status]
                        let json = JSON(json)

                        response.status(.OK).send(json: json)
                    }
                }
            }


        }


    }

    router.post("/polls/vote/:pollid/:option") {
        request, response, next in
        defer{
            next()
        }

        //ensure both parameters have values
        guard let poll = request.parameters["pollid"],
                let option = request.parameters["option"] else
        {
            try response.status(.badRequest).end()
            return
        }

        //attmept to pull out the poll the user requested
        database.retrieve(poll) { doc, error in

            if let error = error {

                //something went wrong
                let errorMessage = error.localizedDescription
                let status = ["status": "error1", "message": errorMessage]
                let result = ["result": status]
                let json = JSON(result)

                response.status(.notFound).send(json: json)

                next()
            } else if let doc = doc {

                // update the document
                var newDocument = doc
                let id = doc["_id"].stringValue
                let rev = doc["_rev"].stringValue

                if option == "1" {
                    newDocument["votes1"].intValue += 1
                } else if option == "2" {
                    newDocument["votes2"].intValue += 1
                }

                database.update(id, rev: rev, document: newDocument) {
                    rev, doc, error in
                    defer{next()}

                    if let error = error {
                        let status = ["status": "error2"]
                        let result = ["result": status]
                        let json = JSON(result)

                        response.status(.conflict).send(json: json)
                    } else {
                        let status = ["status": "ok"]
                        let result = ["result": status]
                        let json = JSON(result)

                        response.status(.OK).send(json: json)
                    }
                }
            }
        }
    }

    Kitura.addHTTPServer(onPort: 8090, with: router)
    Kitura.run()
