//
//  PointOfInterest.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  Every category MapKit ships — 84 of them — GENERATED from
//  MKPointOfInterestCategory.h in the installed SDK rather than typed by hand,
//  so the list cannot drift from Apple's.
//
//  The raw value is the category's own string, and the MapKit value is built
//  from it rather than from the static constant. That is deliberate: several
//  categories are gated to a newer OS than this package's floor, and going
//  through the constants would either drop them from the API or force the
//  whole library up to macOS 27. Built from the string, all 84 compile
//  everywhere; one the running OS has never heard of simply matches nothing.
//  Verified 2026-09-05 that a category made this way compares equal to the
//  constant and filters correctly.
//
//  Regenerate from:
//    $(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/
//      MapKit.framework/Headers/MKPointOfInterestCategory.h
//

import Foundation
import MapKit

/// A kind of place MapKit can filter by.
public enum PointOfInterest: String, CaseIterable, Sendable, Codable {
    case atm = "MKPOICategoryATM"
    case airport = "MKPOICategoryAirport"
    case airportTerminal = "MKPOICategoryAirportTerminal"
    case amusementPark = "MKPOICategoryAmusementPark"
    case animalService = "MKPOICategoryAnimalService"
    case aquarium = "MKPOICategoryAquarium"
    case automotiveDealership = "MKPOICategoryAutomotiveDealership"
    case automotiveRepair = "MKPOICategoryAutomotiveRepair"
    case bakery = "MKPOICategoryBakery"
    case bank = "MKPOICategoryBank"
    case baseball = "MKPOICategoryBaseball"
    case basketball = "MKPOICategoryBasketball"
    case beach = "MKPOICategoryBeach"
    case beauty = "MKPOICategoryBeauty"
    case bowling = "MKPOICategoryBowling"
    case brewery = "MKPOICategoryBrewery"
    case cafe = "MKPOICategoryCafe"
    case campground = "MKPOICategoryCampground"
    case carRental = "MKPOICategoryCarRental"
    case castle = "MKPOICategoryCastle"
    case commercialVehicleDealership = "MKPOICategoryCommercialVehicleDealership"
    case conventionCenter = "MKPOICategoryConventionCenter"
    case distillery = "MKPOICategoryDistillery"
    case evCharger = "MKPOICategoryEVCharger"
    case fairground = "MKPOICategoryFairground"
    case fireStation = "MKPOICategoryFireStation"
    case fishing = "MKPOICategoryFishing"
    case fitnessCenter = "MKPOICategoryFitnessCenter"
    case foodMarket = "MKPOICategoryFoodMarket"
    case fortress = "MKPOICategoryFortress"
    case gasStation = "MKPOICategoryGasStation"
    case goKart = "MKPOICategoryGoKart"
    case golf = "MKPOICategoryGolf"
    case hiking = "MKPOICategoryHiking"
    case hospital = "MKPOICategoryHospital"
    case hotel = "MKPOICategoryHotel"
    case informationBooth = "MKPOICategoryInformationBooth"
    case kayaking = "MKPOICategoryKayaking"
    case landmark = "MKPOICategoryLandmark"
    case laundry = "MKPOICategoryLaundry"
    case library = "MKPOICategoryLibrary"
    case mailbox = "MKPOICategoryMailbox"
    case marina = "MKPOICategoryMarina"
    case miniGolf = "MKPOICategoryMiniGolf"
    case motorbikeDealership = "MKPOICategoryMotorbikeDealership"
    case movieTheater = "MKPOICategoryMovieTheater"
    case museum = "MKPOICategoryMuseum"
    case musicVenue = "MKPOICategoryMusicVenue"
    case nationalMonument = "MKPOICategoryNationalMonument"
    case nationalPark = "MKPOICategoryNationalPark"
    case nightlife = "MKPOICategoryNightlife"
    case park = "MKPOICategoryPark"
    case parking = "MKPOICategoryParking"
    case pharmacy = "MKPOICategoryPharmacy"
    case picnicArea = "MKPOICategoryPicnicArea"
    case planetarium = "MKPOICategoryPlanetarium"
    case police = "MKPOICategoryPolice"
    case postOffice = "MKPOICategoryPostOffice"
    case publicTransport = "MKPOICategoryPublicTransport"
    case rvPark = "MKPOICategoryRVPark"
    case rangerStation = "MKPOICategoryRangerStation"
    case restArea = "MKPOICategoryRestArea"
    case restaurant = "MKPOICategoryRestaurant"
    case restroom = "MKPOICategoryRestroom"
    case rockClimbing = "MKPOICategoryRockClimbing"
    case scenicView = "MKPOICategoryScenicView"
    case school = "MKPOICategorySchool"
    case skatePark = "MKPOICategorySkatePark"
    case skating = "MKPOICategorySkating"
    case skiing = "MKPOICategorySkiing"
    case soccer = "MKPOICategorySoccer"
    case spa = "MKPOICategorySpa"
    case stadium = "MKPOICategoryStadium"
    case store = "MKPOICategoryStore"
    case surfing = "MKPOICategorySurfing"
    case swimming = "MKPOICategorySwimming"
    case tennis = "MKPOICategoryTennis"
    case theater = "MKPOICategoryTheater"
    case ticketOffice = "MKPOICategoryTicketOffice"
    case university = "MKPOICategoryUniversity"
    case visitorCenter = "MKPOICategoryVisitorCenter"
    case volleyball = "MKPOICategoryVolleyball"
    case winery = "MKPOICategoryWinery"
    case zoo = "MKPOICategoryZoo"

    /// The MapKit value.
    public var category: MKPointOfInterestCategory {
        MKPointOfInterestCategory(rawValue: rawValue)
    }

    /// A readable name — `evCharger` reads as "EV charger".
    public var displayName: String {
        let stripped = rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
        var words = ""
        for (index, character) in stripped.enumerated() {
            if character.isUppercase, index > 0,
               !(stripped[stripped.index(stripped.startIndex, offsetBy: index - 1)].isUppercase) {
                words.append(" ")
            }
            words.append(character)
        }
        return words
    }

    /// Reads what someone would type — `restaurant`, `gas-station`,
    /// `EV Charger`, or the raw `MKPOICategoryRestaurant`.
    public init?(alias: String) {
        let key = alias.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "mkpoicategory", with: "")
        guard let match = PointOfInterest.allCases.first(where: {
            $0.name.lowercased() == key
        }) else { return nil }
        self = match
    }

    /// The category as MapKit returned it.
    public init?(_ category: MKPointOfInterestCategory) {
        self.init(rawValue: category.rawValue)
    }

    /// The short name, without the `MKPOICategory` prefix.
    public var name: String {
        rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
    }
}
