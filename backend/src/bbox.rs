use serde::Serialize;

#[derive(Debug, Clone, Copy, Serialize, PartialEq)]
pub struct Bbox {
    pub west: f64,
    pub south: f64,
    pub east: f64,
    pub north: f64,
}

impl Bbox {
    pub const BERLIN: Bbox = Bbox {
        west: 13.0,
        south: 52.3,
        east: 13.8,
        north: 52.7,
    };

    pub fn parse(s: &str) -> Result<Self, String> {
        let parts: Vec<&str> = s.split(',').collect();
        if parts.len() != 4 {
            return Err("bbox must be in the format: west,south,east,north".into());
        }
        let coord = |raw: &str| {
            raw.trim()
                .parse::<f64>()
                .map_err(|_| format!("invalid bbox coordinate: {raw}"))
        };
        Ok(Self {
            west: coord(parts[0])?,
            south: coord(parts[1])?,
            east: coord(parts[2])?,
            north: coord(parts[3])?,
        })
    }

    pub fn to_query_string(&self) -> String {
        format!("{},{},{},{}", self.west, self.south, self.east, self.north)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_valid() {
        let b = Bbox::parse("13.0,52.3,13.8,52.7").unwrap();
        assert_eq!(b, Bbox::BERLIN);
    }

    #[test]
    fn parse_with_whitespace() {
        let b = Bbox::parse(" 13.0 , 52.3 , 13.8 , 52.7 ").unwrap();
        assert_eq!(b, Bbox::BERLIN);
    }

    #[test]
    fn parse_negative_coords() {
        let b = Bbox::parse("-74.0,-40.7,-73.9,-40.6").unwrap();
        assert!((b.west - -74.0).abs() < 1e-9);
        assert!((b.south - -40.7).abs() < 1e-9);
    }

    #[test]
    fn parse_too_few_parts() {
        assert!(Bbox::parse("13.0,52.3,13.8").is_err());
    }

    #[test]
    fn parse_too_many_parts() {
        assert!(Bbox::parse("13.0,52.3,13.8,52.7,99.0").is_err());
    }

    #[test]
    fn parse_empty_string() {
        assert!(Bbox::parse("").is_err());
    }

    #[test]
    fn parse_non_numeric() {
        let err = Bbox::parse("abc,52.3,13.8,52.7").unwrap_err();
        assert!(err.contains("invalid bbox coordinate"));
    }

    #[test]
    fn round_trip_to_query_string() {
        let b = Bbox::parse("12.9,52.25,13.9,52.75").unwrap();
        assert_eq!(b.to_query_string(), "12.9,52.25,13.9,52.75");
    }
}
