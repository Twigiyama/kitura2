import Kitura
import HeliumLogger
import LoggerAPI
import SwiftyJSON


HeliumLogger.use()

let router = Router()




router.get("/polls/list") {
    request, response, next in
    defer { next() }

    let status = ["status": "ok"]
    let result = ["result": status]
    let json = JSON(result)

    response.status(.OK).send(json: json)
}

router.post("/polls/create") {
    request, response, next in
    defer{ next() }
}

router.post("/polls/vote/:pollid/:option") {
    requst, response, next in
    defer{ next() }
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()
