import Foundation

@main
struct ContactSearchTests {
    static func main() {
        let equivalentNames = [
            ("Саша", "Sasha"),
            ("САША", "sAsHa"),
            ("Иван Петров", "Ivan Petrov"),
            ("Жанна", "Zhanna"),
            ("Юлия", "Yuliya"),
            ("Яна", "Yana"),
            ("Харитон", "Khariton"),
            ("Щукин", "Shchukin"),
            ("Чайковский", "Chaykovskiy"),
            ("Артём", "Artyom"),
            ("Дарья", "Darya"),
            ("Саша Smith", "Sasha Smith")
        ]
        for (cyrillic, latin) in equivalentNames {
            assert(ContactSearch.normalized(cyrillic) == ContactSearch.normalized(latin),
                   "Expected equivalent search keys: \(cyrillic), \(latin)")
        }

        let matchingQueries = [
            ("Саша Петров", "SASHA"),
            ("Sasha Petrov", "САША"),
            ("Саша Петров", "Pet"),
            ("Sasha Petrov", "Пет"),
            ("Артём", "tyo"),
            ("Иван", "ив"),
            ("Alice", "ALI")
        ]
        for (name, query) in matchingQueries {
            assert(ContactSearch.normalized(name).contains(ContactSearch.normalized(query)),
                   "Expected query \(query) to match \(name)")
        }

        assert(!ContactSearch.normalized("Саша").contains(ContactSearch.normalized("Masha")))
        assert(!ContactSearch.normalized("Sasha").contains(ContactSearch.normalized("Маша")))
        assert(ContactSearch.normalized("") == "")
        assert(ContactSearch.normalized("ьъ") == "")
        assert(ContactSearch.normalized("+7 (999) 123-45-67") == "+7 (999) 123-45-67")
        let phoneFormats = ["+7 999 123-45-67", "79991234567", "9991234567"]
        var phoneChecks = 0
        for stored in phoneFormats {
            let index = ContactSearch.Index(name: "Саша", phoneNumbers: [stored])
            for query in phoneFormats + ["999", "123-45", "45-67", "(999) 123", " 999\u{00A0}123 "] {
                assert(index.matchesPhoneNumber(ContactSearch.phoneDigits(query)),
                       "Expected phone query \(query) to match \(stored)")
                phoneChecks += 1
            }
            for query in ["", " +()- ", "555", "12345678", "Саша"] {
                assert(!index.matchesPhoneNumber(ContactSearch.phoneDigits(query)),
                       "Unexpected phone match: \(query), \(stored)")
                phoneChecks += 1
            }
        }

        let multiplePhones = ContactSearch.Index(name: "Sasha", phoneNumbers: ["+7 111 222-33-44", "+7 (999) 123-45-67"])
        assert(multiplePhones.matchesPhoneNumber(ContactSearch.phoneDigits("999 123")))
        assert(multiplePhones.matchesPhoneNumber(ContactSearch.phoneDigits("7999")))
        assert(!ContactSearch.Index(name: "Саша", phoneNumbers: []).matchesPhoneNumber("999"))
        assert(ContactSearch.Index(name: "Саша", phoneNumbers: ["+7 999"]).name == ContactSearch.normalized("Sasha"))
        print("ContactSearch: all \(equivalentNames.count + matchingQueries.count + 5 + phoneChecks + 4) checks passed")
    }
}
