//
// Copyright (C) 2019-present Instructure, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import XCTest
import SwiftUITest

enum LoginFindSchool: String, CaseIterable, ElementWrapper {
  case searchField
}

enum LoginStart {
    static var findMySchool: Element {
        return app.find(label: "Find my school")
    }

    static func previousUser(studentNumber: String) -> Element {
        return app.find(label: "Student \(studentNumber)")
    }
}

enum CanvasLogin {
    static var emailTextField: Element {
        return XCUIApplication().webViews.textFields["Email"].toElement(testCase)
    }

    static var passwordTextField: Element {
        return XCUIApplication().webViews.secureTextFields["Password"].toElement(testCase)
    }

    static var logInButton: Element {
        return XCUIApplication().webViews.buttons["Log In"].toElement(testCase)
    }
}

enum RyanaLogin {
    static var ldapButton: Element {
        return XCUIApplication().webViews.staticTexts["LDAP"].toElement(testCase)
    }
}

enum Dashboard {
    static var courses: Element {
        return app.find(label: "Courses")
    }

    static func courseCard(id: String) -> Element {
        return app.find(id: "course-\(id)")
    }

    static var dashboardTab: Element {
        return app.find(label: "Dashboard")
    }

    static var dashboardList: Element {
        return app.find(id: "favorited-course-list.profile-btn")
    }

    static var changeUser: Element {
        return app.find(label: "Change User")
    }
}

class LoginTests: CanvasUITests {

    func testCanvasLoginToDashboard() {
       loginUser(username: "student1", password: "password")

        // Dashboard
        XCTAssert(Dashboard.courses.exists)
        XCTAssert(Dashboard.courseCard(id: "247").exists)
        XCTAssert(Dashboard.dashboardTab.exists)
    }

    func testLDAPLoginToDashboard() {
        // Find my school
        XCTAssert(LoginStart.findMySchool.exists)
        LoginStart.findMySchool.tap()
        LoginFindSchool.searchField.typeText("ryana\r")

        // Ryana Web View
        RyanaLogin.ldapButton.waitToExist(Timeout(value: 10))
        RyanaLogin.ldapButton.tap()

        // Email
        CanvasLogin.emailTextField.waitToExist(Timeout(value: 10))
        CanvasLogin.emailTextField.tap()
        CanvasLogin.emailTextField.typeText("ldapmobiletest")

        // Password
        CanvasLogin.passwordTextField.waitToExist(Timeout(value: 10))
        CanvasLogin.passwordTextField.tap()
        CanvasLogin.passwordTextField.typeText("mobiletesting123")

        // Submit
        CanvasLogin.logInButton.tap()

        XCTAssert(Dashboard.courses.exists)
        XCTAssert(Dashboard.dashboardTab.exists)
    }

    func testMultipleUsers() {
        loginUser(username: "student1", password: "password")

        // Change User
        Dashboard.dashboardList.tap()
        Dashboard.changeUser.tap()

        loginUser(username: "student2", password: "password")

        // Change User
        Dashboard.dashboardList.tap()
        Dashboard.changeUser.tap()

        // Previous Users
        XCTAssert(LoginStart.previousUser(studentNumber: "One").exists)
        XCTAssert(LoginStart.previousUser(studentNumber: "Two").exists)
    }

    func loginUser(username: String, password: String) {
        // Find my school
        XCTAssert(LoginStart.findMySchool.exists)
        LoginStart.findMySchool.tap()
        LoginFindSchool.searchField.typeText("iosauto\r")

        // Email
        CanvasLogin.emailTextField.waitToExist(Timeout(value: 10))
        CanvasLogin.emailTextField.tap()
        CanvasLogin.emailTextField.typeText(username)

        // Password
        CanvasLogin.passwordTextField.waitToExist(Timeout(value: 10))
        CanvasLogin.passwordTextField.tap()
        CanvasLogin.passwordTextField.typeText(password)

        // Submit
        CanvasLogin.logInButton.tap()
    }
}