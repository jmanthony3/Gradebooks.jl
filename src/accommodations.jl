export AccommodationType, Accommodation



@enum AccommodationType begin
    AccommodationExtendedAssignmentTime
    AccommodationExtendedTestTime          # with multiplier: 1.5x, 2.0x, etc.
    AccommodationModifiedAttendance
    AccommodationNoteTakingAssistance
    AccommodationAudioRecordingPermission
    AccommodationPreferentialSeating
    AccommodationStepOutPermission
    AccommodationTestingCenterRequired
    AccommodationScribeRequired
    AccommodationLaptopForExams
    AccommodationVirtualAttendance
    AccommodationPriorityRegistration
    AccommodationOther
end

struct Accommodation
    type::AccommodationType
    details::String                  # full text or key parameters
    multiplier::Float64              # e.g. 1.5 for time-and-a-half
    notes::String
    source_date::Date                # when ODAS letter was received
end
function Accommodation(type::AccommodationType; details="", multiplier=1.0, notes="", source_date=today())
    Accommodation(type, details, multiplier, notes, source_date)
end
