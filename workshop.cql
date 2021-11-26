/////////////////////////////////////////////////////////////////////////////
// Author: Sixing Huang
// Description: Analyzing the KEGG Disease Data with a Graph Database
// Authors Note: 
// This article shows how to:
// 1. Identify multipurpose drugs.
// 2. Show details about some pathogens such as SARS-CoV-2.
// 
// Repackaged: Maruthi Prithivirajan 
// For: NUS Datathon - Neo4j Workshop November 2021
// Original Blog Post: https://towardsdatascience.com/neo4j-for-diseases-959dffb5b479
// Original Code: https://github.com/dgg32/kegg_disease
/////////////////////////////////////////////////////////////////////////////



/////////////////////////////////////////////////////////////////////////////
///////////////////////////////Data Ingestion////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// As part of the best practices when start creating the phsical model and ingesting data, 
// always start by creating Indexes it helps improve the latency in data ingestion and querying.
// Here were creating Unique Indexes for the following Node properties to avoid duplicate entries:
CREATE CONSTRAINT disease_ko IF NOT EXISTS ON (n:Disease) ASSERT n.ko IS UNIQUE;
CREATE CONSTRAINT drug_ko IF NOT EXISTS ON (n:Drug) ASSERT n.ko IS UNIQUE;
CREATE CONSTRAINT pathogen_ko IF NOT EXISTS ON (n:Pathogen) ASSERT n.ko IS UNIQUE;
CREATE INDEX disease_name FOR (d:Disease) ON (d.name);
CREATE INDEX pathogen_name FOR (p:Pathogen) ON (p.name);
CREATE INDEX drug_name FOR (d:Drug) ON (d.name);

// Load Diseases dataset from GitHub Gist to create disease nodes
LOAD CSV WITH HEADERS FROM 'https://gist.githubusercontent.com/maruthiprithivi/8b4585e71c0a771aceaa2f12e2413792/raw/233af7b39c7df5d0241719366628ec0269ff7c4f/disease.csv' AS row 
MERGE (n:Disease {name: row.name, ko: row.ko, description: row.description, disease_category:row.disease_category});

// Load Drugs dataset from GitHub Gist to create drug nodes
LOAD CSV WITH HEADERS FROM 'https://gist.githubusercontent.com/maruthiprithivi/8b4585e71c0a771aceaa2f12e2413792/raw/233af7b39c7df5d0241719366628ec0269ff7c4f/drug.csv' AS row 
MERGE (n:Drug {name: row.name, ko: row.ko});

// Load Pathogens dataset from GitHub Gist to create pathogen nodes
LOAD CSV WITH HEADERS FROM 'https://gist.githubusercontent.com/maruthiprithivi/8b4585e71c0a771aceaa2f12e2413792/raw/233af7b39c7df5d0241719366628ec0269ff7c4f/pathogen.csv' AS row 
MERGE (n:Pathogen {name: row.name, ko: row.ko, taxonomy: row.taxonomy});

// Load Disease-Drug dataset from GitHub Gist to create disease to drug relationships
// `TREATS` is a relationship type that indicates that a drug treats a disease
LOAD CSV WITH HEADERS FROM 'https://gist.githubusercontent.com/maruthiprithivi/8b4585e71c0a771aceaa2f12e2413792/raw/233af7b39c7df5d0241719366628ec0269ff7c4f/drug_disease.csv' AS row 
MATCH (n1:Drug {ko: row.from}) 
MATCH (n2:Disease {ko: row.to}) 
MERGE (n1)-[r:TREATS]->(n2);

// Load Disease-Pathogen dataset from GitHub Gist to create disease to pathogen relationships
// `CAUSES` is a relationship type that indicates that the pathogen causes the disease
LOAD CSV WITH HEADERS FROM 'https://gist.githubusercontent.com/maruthiprithivi/8b4585e71c0a771aceaa2f12e2413792/raw/233af7b39c7df5d0241719366628ec0269ff7c4f/pathogen_disease.csv' AS row 
MATCH (n1:Pathogen {ko: row.from}) 
MATCH (n2:Disease {ko: row.to}) 
MERGE (n1)-[r:CAUSES]->(n2);

// Now to check the schema of the Graph created in the database
// Interactively explore the directional realtionship types, available node properties and indexes created
CALL db.schema.visualization;

/////////////////////////////////////////////////////////////////////////////
//////////////////////////// Data Exploration ///////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Quick data exploration
// Counting distinct pathogens in the Graph
MATCH (p:Pathogen) RETURN COUNT(DISTINCT p) AS pathogen_count;

// Counting distinct drugs in the Graph
MATCH (dr:Drug) RETURN COUNT(DISTINCT dr) AS drug_count;

// Counting distinct diseases in the Graph
MATCH (di:Disease) RETURN COUNT(DISTINCT di) AS disease_count;

// Now to query the Graph to explore the nodes relationships. 
// We can observe that there small commuinities and some diads (stranglers) in the graph
MATCH p=(n:Disease)<-[]-() RETURN p; 

// Lets check out the top disesase categories in the graph
MATCH (d:Disease) RETURN d.disease_category, 
COUNT(d.disease_category) as count ORDER BY count 
DESC LIMIT 10;

// Now for some string operations to look at the Pathogen groupings by their domain
// "Again, to my surprise, bacteria, not the viruses, 
// are the most frequent pathogens in the data..."
MATCH (v:Pathogen) RETURN split(v.taxonomy, "; ")[0] as domain, 
COUNT(split(v.taxonomy, "; ")[0]) as count ORDER BY count DESC;

// Now to take a closer look into Viruses
// Riboviria --> SARS-CoV-2, SARS coronavirus, 
// 2002–2004 SARS outbreak, HIV and hepatitis viruses
MATCH (v:Pathogen) WHERE v.taxonomy contains "virus" 
RETURN split(v.taxonomy, "; ")[0] + "; " +  split(v.taxonomy, "; ")[1] as domain, 
COUNT(split(v.taxonomy, "; ")[0] + "; " +  split(v.taxonomy, "; ")[1]) as count ORDER BY count DESC;


// We hav been looking at the disease categories,
// domains and closer look at viruses. 
// Now let's look at the drugs available for infectious diseases
MATCH (dr:Drug)-[]->(di:Disease) WHERE di.disease_category = "Infectious disease" 
RETURN COUNT(DISTINCT(dr)) AS Drugs_Available_For_Infectious_Diseases;

/////////////////////////////////////////////////////////////////////////////
///////////////////////// Connected Data Exploration ////////////////////////
/////////////////////////////////////////////////////////////////////////////

// Let's find multipurpose drugs that are available
MATCH (dr:Drug) -[r:TREATS]->(di:Disease) 
RETURN dr.name as drug, COUNT(r) as count 
ORDER BY count DESC LIMIT 10;

// Exploring the diseases the drugs are treating
MATCH (a:Drug)-[r:TREATS]->(b:Disease)
WITH a, COUNT(r) AS indicationCount
ORDER BY indicationCount DESC LIMIT 10
MATCH (a)-[r:TREATS]->(b:Disease)
RETURN a, r, b;

// Taking a closer look at the top two drugs.
// Checking the top disease categories covered by the 
// drug and the number of diseases under the category
MATCH (dr:Drug)-[]->(di:Disease) WHERE dr.name="Prednisolone sodium phosphate" 
RETURN  di.disease_category AS Disease_Category, count(di.disease_category) AS Disease_Count 
ORDER BY Disease_Count DESC LIMIT 10;

// Now to check out the diseases under these categories
MATCH (dr:Drug)-[]->(di:Disease) WHERE dr.name="Prednisolone sodium phosphate" 
AND (di.disease_category = "Lung disease" or di.disease_category="Infectious disease") 
RETURN di.name AS Disease_Name, di.disease_category AS Disease_Category ORDER BY Disease_Category;

// Based on the results prednisolone is not only used to treat immune system disease, 
// but also infectious diseases such as trichinosis and tuberculosis

// Now let's look into Pathogens recorded in the KEGG dataset 
MATCH (p:Pathogen) -[r:CAUSES]->(di:Disease) 
RETURN p.name, COUNT(r) as count ORDER BY count DESC LIMIT 10; 
// The top two are papillomaviruses that can 
// lead to different kinds of cancer in human, 
// this is based on Wikipedia data (https://en.wikipedia.org/wiki/Human_papillomavirus_infection)

// Let's check the diseases that are caused by these pathogens and explore the graph
MATCH a=(p:Pathogen)-[r:CAUSES]->(di:Disease) 
WHERE p.name = "Human papillomavirus type 16" or 
p.name = "Human papillomavirus type 18" RETURN a;

// I hope this serves as a good starting point for you start to 
// exploring Labelled Property Graph in Neo4j Graph Data Platform 


/////////////////////////////////////////////////////////////////////////////
/////////////////////// Continue Exploration in Bloom ///////////////////////
/////////////////////////////////////////////////////////////////////////////

